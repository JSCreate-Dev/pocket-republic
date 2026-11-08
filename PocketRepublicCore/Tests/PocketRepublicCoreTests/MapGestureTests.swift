import XCTest
@testable import PocketRepublicCore

final class MapGestureTests: XCTestCase {
    func testTwoFingersPanAndPinchAndDoNotAddARoadPoint() {
        var gesture = MapGesturePolicy()
        gesture.roadMode = true
        gesture.began(activeFingers: 1)
        XCTAssertEqual(
            gesture.moved(activeFingers: 1, panX: 4, panY: 1, oldDistance: 0, newDistance: 0, treatAsDrag: true),
            .roadPoint)
        gesture.began(activeFingers: 2)
        XCTAssertEqual(
            gesture.moved(activeFingers: 2, panX: 10, panY: -4, oldDistance: 40, newDistance: 80, treatAsDrag: true),
            .navigate(panX: 10, panY: -4, scaleFactor: 0.5))
        XCTAssertFalse(gesture.ended(remainingFingers: 1))
        XCTAssertEqual(
            gesture.moved(activeFingers: 1, panX: 6, panY: 6, oldDistance: 0, newDistance: 0, treatAsDrag: true),
            .ignore)
        XCTAssertFalse(gesture.ended(remainingFingers: 0))
        XCTAssertFalse(gesture.multiFinger)
    }

    func testAStillSingleFingerIsTheOnlyRoadTap() {
        var tap = MapGesturePolicy()
        tap.roadMode = true
        tap.began(activeFingers: 1)
        XCTAssertTrue(tap.ended(remainingFingers: 0))

        var pinch = MapGesturePolicy()
        pinch.roadMode = true
        pinch.began(activeFingers: 2)
        XCTAssertFalse(pinch.ended(remainingFingers: 0))
    }

    func testInspectPanUsesTheSameDeltaAndDoesNotTap() {
        var gesture = MapGesturePolicy()
        gesture.began(activeFingers: 1)
        XCTAssertEqual(
            gesture.moved(activeFingers: 1, panX: 12, panY: -3, oldDistance: 0, newDistance: 0, treatAsDrag: true),
            .navigate(panX: 12, panY: -3, scaleFactor: nil))
        XCTAssertFalse(gesture.ended(remainingFingers: 0))
    }

    func testCameraPanThenPinchKeepsTheAnchor() {
        let pan = MapCameraNudge.applying(x: 100, y: 50, scale: 1,
                                          panX: 10, panY: -4,
                                          anchorX: 0, anchorY: 0, scaleFactor: nil)
        XCTAssertEqual(pan, MapCameraNudge(x: 90, y: 54, scale: 1))

        let pinch = MapCameraNudge.applying(x: 100, y: 50, scale: 1,
                                            panX: 0, panY: 0,
                                            anchorX: 130, anchorY: 40, scaleFactor: 0.8)
        XCTAssertEqual(pinch.x, 106, accuracy: 0.001)
        XCTAssertEqual(pinch.y, 48, accuracy: 0.001)
        XCTAssertEqual(pinch.scale, 0.8, accuracy: 0.001)

        let floored = MapCameraNudge.applying(x: 100, y: 50, scale: 1,
                                              panX: 0, panY: 0,
                                              anchorX: 130, anchorY: 40, scaleFactor: 0.5)
        XCTAssertEqual(floored.scale, 0.55, accuracy: 0.001)
        XCTAssertEqual(floored.x, 113.5, accuracy: 0.001)
        XCTAssertEqual(floored.y, 45.5, accuracy: 0.001)

        let both = MapCameraNudge.applying(x: 100, y: 50, scale: 1,
                                           panX: 10, panY: 0,
                                           anchorX: 130, anchorY: 40, scaleFactor: 1)
        XCTAssertEqual(both.x, 90, accuracy: 0.001)
        XCTAssertEqual(both.y, 50, accuracy: 0.001)
        XCTAssertEqual(both.scale, 1, accuracy: 0.001)
    }

    func testLeavingTheIslandDropsOnlyBuildHolds() {
        var session = IslandSessionHold(
            toolIsInspect: false, catalogOpen: true, roadDraftCount: 4, hasPlacement: true,
            modalTokens: ["build", "catalog", "demolish", "new-city"])
        session.leaveIsland()
        XCTAssertTrue(session.toolIsInspect)
        XCTAssertFalse(session.catalogOpen)
        XCTAssertEqual(session.roadDraftCount, 0)
        XCTAssertFalse(session.hasPlacement)
        XCTAssertEqual(session.modalTokens, ["demolish", "new-city"])
    }
}
