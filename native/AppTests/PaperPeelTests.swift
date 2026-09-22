import XCTest
import SwiftUI
@testable import Suji

final class PaperPeelTests: XCTestCase {
    func testReachablePullCompletesAcrossWidthsButExploratoryPullDoesNot() {
        for width: CGFloat in [280, 350, 468, 520] {
            XCTAssertGreaterThanOrEqual(PaperPeelInteraction.progress(for: CGSize(width: -80, height: -88), width: width), PaperPeelInteraction.revealProgress)
            XCTAssertLessThan(PaperPeelInteraction.progress(for: CGSize(width: -18, height: -20), width: width), PaperPeelInteraction.revealProgress)
        }
    }
    func testWrongDirectionAndVerticalScrollDoNotAcquirePeel() {
        for offset in [CGSize(width: 20, height: 20), CGSize(width: 0, height: -40), CGSize(width: -2, height: -40), CGSize(width: -20, height: 20)] {
            XCTAssertFalse(PaperPeelInteraction.isPeelIntent(offset))
        }
        XCTAssertTrue(PaperPeelInteraction.isPeelIntent(CGSize(width: -8, height: -12)))
    }
    func testPullBackCancelsAndTravelIsBounded() {
        XCTAssertGreaterThan(PaperPeelInteraction.progress(for: CGSize(width: -100, height: -100), width: 350), PaperPeelInteraction.revealProgress)
        XCTAssertLessThan(PaperPeelInteraction.progress(for: CGSize(width: -10, height: -12), width: 350), PaperPeelInteraction.revealProgress)
        XCTAssertEqual(PaperPeelInteraction.progress(for: CGSize(width: 90, height: 80), width: 350), 0)
        XCTAssertEqual(PaperPeelInteraction.progress(for: CGSize(width: -900, height: -900), width: 350), 0.88)
    }
    func testReturningToOriginIsNotATapEvenAfterCrossingThreshold() {
        XCTAssertFalse(PaperPeelInteraction.shouldReveal(at: CGSize(width: -2, height: -2), maximumDistance: 142,
                                                       acquiredPeel: true, width: 350, reduceMotion: false))
        XCTAssertFalse(PaperPeelInteraction.shouldReveal(at: .zero, maximumDistance: 40,
                                                       acquiredPeel: false, width: 350, reduceMotion: false))
        XCTAssertFalse(PaperPeelInteraction.shouldReveal(at: .zero, maximumDistance: 40,
                                                       acquiredPeel: false, width: 350, reduceMotion: true))
        XCTAssertTrue(PaperPeelInteraction.shouldReveal(at: CGSize(width: 1, height: 2), maximumDistance: 3,
                                                      acquiredPeel: false, width: 350, reduceMotion: true))
        XCTAssertTrue(PaperPeelInteraction.shouldReveal(at: CGSize(width: -80, height: -88), maximumDistance: 119,
                                                      acquiredPeel: true, width: 350, reduceMotion: false))
    }

    func testCurlSamplesStayFiniteAcrossSizesAndProgress() {
        for size in [CGSize(width: 280, height: 404), CGSize(width: 350, height: 520), CGSize(width: 350, height: 1400)] {
            for value in stride(from: 0.0, through: 1.0, by: 0.025) {
                let geometry = PaperCurlGeometry(size: size, progress: value)
                let strips = geometry.strips(count: 56)
                XCTAssertFalse(strips.isEmpty)
                XCTAssertLessThanOrEqual(strips.count, 58)
                for strip in strips {
                    let t = strip.transform
                    XCTAssertTrue([t.a,t.b,t.c,t.d,t.tx,t.ty].allSatisfy(\.isFinite))
                    XCTAssertGreaterThanOrEqual(strip.path.boundingRect.minX, -0.001)
                    XCTAssertLessThanOrEqual(strip.path.boundingRect.maxX, size.width + 0.001)
                }
            }
        }
    }
}
