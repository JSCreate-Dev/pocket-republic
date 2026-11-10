#!/usr/bin/env python3
"""Compile the real Game/save boundary on Linux with a minimal Combine shim.
No SwiftUI/SpriteKit mocks or claims of iOS SDK typechecking.
"""
from pathlib import Path
import os, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
swift = os.environ.get('SWIFT_EXEC', 'swiftc')
build = root/'PocketRepublicCore/.build/release'
harness = r'''
import Foundation
import PocketRepublicCore

@main struct SaveChecks {
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let primary = folder.appendingPathComponent("spatial-v1.json")
        let repo = CitySaveRepository(primary: primary)
        var first = WorldGenerator.generate(seed: 42)
        let hash = first.stateHash()
        precondition(try CitySaveCodec.decode(CitySaveCodec.encode(first)).stateHash() == hash)
        _ = try repo.write(first)
        precondition(repo.load().state?.stateHash() == hash && repo.backupSummary() == nil)
        // No-op saves must preserve a real older recovery point.
        var next = first; next.day += 1
        _ = try repo.write(next)
        let backupBytes = try Data(contentsOf: repo.backup)
        _ = try repo.write(next)
        precondition(try Data(contentsOf: repo.backup) == backupBytes)
        precondition(repo.backupSummary()?.day == first.day)
        let primaryBeforeBadBackup = try Data(contentsOf: primary)
        try Data("bad backup".utf8).write(to: repo.backup)
        do { _ = try repo.restore(); preconditionFailure("corrupt backup restored") } catch {}
        precondition(try Data(contentsOf: primary) == primaryBeforeBadBackup)
        try backupBytes.write(to: repo.backup)
        let game = Game(saveLocation: primary)
        precondition(!game.launchReady && !game.send(.setPolicy(first.policy)))
        await game.prepare()
        precondition(game.launchReady && game.saveIssue == nil && game.state.stateHash() == next.stateHash())
        let session = game.citySession
        precondition(await game.restoreBackup())
        precondition(game.citySession != session && game.state.stateHash() == hash)
        // A read failure preserves bytes and does NOT allow saving a placeholder.
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: primary)
        let broken = Game(saveLocation: primary)
        await broken.prepare()
        precondition(broken.saveIssue != nil && !broken.canRetrySave)
        broken.retrySave()
        precondition(try Data(contentsOf: primary) == corrupt)
        precondition(await broken.restoreBackup())
        precondition(try Data(contentsOf: repo.preserved) == corrupt)
        precondition(try Data(contentsOf: repo.backup) == backupBytes)
        // Structurally invalid/checksum-invalid saves cannot be selected.
        let wrong = try JSONEncoder().encode(SpatialSave(formatVersion: 1, checksum: 1, state: first))
        do { _ = try CitySaveCodec.decode(wrong); preconditionFailure("bad checksum accepted") } catch {}
        first.map.road.removeLast()
        let malformed = try JSONEncoder().encode(SpatialSave(formatVersion: 1, checksum: 1, state: first))
        do { _ = try CitySaveCodec.decode(malformed); preconditionFailure("malformed map accepted") } catch {}
        // Missing primary with a backup is recovery, not silent new-city creation.
        try FileManager.default.removeItem(at: primary)
        precondition(repo.load().issue != nil && repo.load().state == nil)
        _ = try repo.restore()
        // Failure rotating a backup must leave both selected state and primary intact.
        try FileManager.default.removeItem(at: repo.backup)
        try FileManager.default.createDirectory(at: repo.backup, withIntermediateDirectories: true)
        let selected = Game(saveLocation: primary)
        await selected.prepare()
        let selectedHash = selected.state.stateHash()
        let original = try Data(contentsOf: primary)
        precondition(!(await selected.startNewCity()))
        precondition(selected.state.stateHash() == selectedHash)
        precondition(try Data(contentsOf: primary) == original)
        precondition(selected.feedback != nil)
        // Unsaved in-memory changes can retry after storage is repaired.
        var policy = selected.state.policy; policy.incomeTaxPercent += 1
        precondition(selected.send(.setPolicy(policy)))
        precondition(selected.saveIssue != nil && selected.canRetrySave)
        let unsavedHash = selected.state.stateHash()
        try FileManager.default.removeItem(at: repo.backup)
        selected.retrySave()
        precondition(selected.saveIssue == nil && !selected.canRetrySave)
        precondition(repo.load().state?.stateHash() == unsavedHash)
        let unreadableBackup = Data("unreadable old backup".utf8)
        try unreadableBackup.write(to: repo.backup)
        var later = selected.state; later.day += 1
        _ = try repo.write(later)
        precondition(try Data(contentsOf: repo.preservedBackup) == unreadableBackup)
        let freshFolder = folder.appendingPathComponent("fresh")
        try FileManager.default.createDirectory(at: freshFolder, withIntermediateDirectories: true)
        let freshURL = freshFolder.appendingPathComponent("spatial-v1.json")
        let fresh = Game(saveLocation: freshURL)
        await fresh.prepare()
        precondition(fresh.launchReady && fresh.saveIssue == nil && fresh.state.citizens.count == 16)
        let freshHash = fresh.state.stateHash()
        await fresh.prepare()
        precondition(fresh.state.stateHash() == freshHash)
        precondition(try CitySaveCodec.decode(Data(contentsOf: freshURL)).stateHash() == freshHash)
        print("Save recovery passed: real Game launch gate, codec/checksum/structure, rolling/no-op backup, explicit restore/session reset, corrupt/missing-file preservation, failed replacement and in-memory save retry")
    }
}
'''
# precondition's autoclosure cannot itself await or throw. Lift those expressions.
import re
harness = re.sub(r'precondition\(try (.+)\)', lambda m: 'let check'+str(m.start())+' = try '+m.group(1)+'\n        precondition(check'+str(m.start())+')', harness)
harness = harness.replace('precondition(await game.restoreBackup())', 'let restoredGame = await game.restoreBackup(); precondition(restoredGame)')
harness = harness.replace('precondition(await broken.restoreBackup())', 'let restoredBroken = await broken.restoreBackup(); precondition(restoredBroken)')
harness = harness.replace('precondition(!(await selected.startNewCity()))', 'let replaced = await selected.startNewCity(); precondition(!replaced)')
with tempfile.TemporaryDirectory(prefix='pocket-save-check-') as folder:
    temp = Path(folder)
    shim = temp/'Combine.swift'
    shim.write_text('public protocol ObservableObject: AnyObject {}\n@propertyWrapper public struct Published<Value> { public var wrappedValue: Value; public init(wrappedValue: Value) { self.wrappedValue = wrappedValue } }\n')
    subprocess.run([swift,'-parse-as-library','-emit-module','-emit-object','-module-name','Combine',str(shim),'-emit-module-path',str(temp/'Combine.swiftmodule'),'-o',str(temp/'Combine.o')],check=True)
    copy = (root/'PocketRepublic/Views/CityFootprintModel.swift').read_text().split('extension IntentRejection {',1)[1].split('/// Tiles within',1)[0]
    main = temp/'checks.swift'; main.write_text(harness + '\nextension IntentRejection {' + copy)
    binary = temp/'check'
    subprocess.run([swift,'-parse-as-library','-I',str(temp),'-I',str(build/'Modules'),str(root/'PocketRepublic/Simulation/Game.swift'),str(main),str(temp/'Combine.o'),*map(str,(build/'PocketRepublicCore.build').glob('*.o')),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
