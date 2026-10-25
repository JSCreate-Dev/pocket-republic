import Foundation

public enum SaveDecodeResult {
    case missing
    case loaded(Republic)
    case corrupt
    case unsupportedVersion(Int)
}

public enum SaveCodec {
    private struct SchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    public static func decode(_ data: Data?) -> SaveDecodeResult {
        guard let data else { return .missing }
        do {
            let probe = try JSONDecoder().decode(SchemaProbe.self, from: data)
            let version = probe.schemaVersion ?? 1
            guard version == Republic.currentSchemaVersion else { return .unsupportedVersion(version) }
            let republic = try JSONDecoder().decode(Republic.self, from: data)
            guard republic.lastSavedAtEpochSeconds.isFinite,
                  republic.pending == nil || republic.pending == "revolution" || republic.pending == "scandal" else {
                return .corrupt
            }
            return .loaded(republic)
        } catch {
            return .corrupt
        }
    }

    public static func encode(_ state: Republic) throws -> Data {
        try JSONEncoder().encode(state)
    }
}
