import XCTest
@testable import Qianshou

final class CoordinateMapperTests: XCTestCase {

    // 模拟器窗口 456x972（含标题栏 28pt），内容区 456x944，自校准后 topInset=28
    private let contentInFrame = CGRect(x: 0, y: 28.0 / 972.0, width: 1, height: 944.0 / 972.0)

    func testDrawRectAspectFit() {
        // 视图 400x800（比例 0.5），帧 456x972（比例 0.469）：按高度缩放受限 → 375.3x800
        let rect = CoordinateMapper.drawRect(frame: CGSize(width: 456, height: 972),
                                             viewSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(rect?.width ?? 0, 375.31, accuracy: 0.01)
        XCTAssertEqual(rect?.height ?? 0, 800, accuracy: 0.01)
        XCTAssertEqual(rect?.minX ?? -1, (400 - 375.31) / 2, accuracy: 0.01)
        XCTAssertEqual(rect?.minY ?? -1, 0, accuracy: 0.01)
    }

    func testViewToFrameInBounds() {
        // 视图中心 → 帧归一化 (0.5, 0.5)
        let p = CoordinateMapper.viewToFrame(CGPoint(x: 200, y: 400),
                                             frame: CGSize(width: 456, height: 972),
                                             viewSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(p?.x ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(p?.y ?? -1, 0.5, accuracy: 0.001)
    }

    func testViewToFrameOutOfBounds() {
        // 画面外的点（横向偏移超出 draw rect）→ nil
        let p = CoordinateMapper.viewToFrame(CGPoint(x: 399, y: 400),
                                             frame: CGSize(width: 456, height: 972),
                                             viewSize: CGSize(width: 400, height: 800))
        XCTAssertNil(p)
    }

    func testFrameToContent() {
        // 帧顶部（标题栏区域）→ nil
        XCTAssertNil(CoordinateMapper.frameToContent(CGPoint(x: 0.5, y: 0.01), contentInFrame: contentInFrame))
        // 内容区左上角 → (0, 0)
        let topLeft = CoordinateMapper.frameToContent(CGPoint(x: 0, y: contentInFrame.minY), contentInFrame: contentInFrame)
        XCTAssertEqual(topLeft?.x ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(topLeft?.y ?? -1, 0, accuracy: 0.001)
        // 内容区中心
        let center = CoordinateMapper.frameToContent(CGPoint(x: 0.5, y: contentInFrame.midY), contentInFrame: contentInFrame)
        XCTAssertEqual(center?.x ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(center?.y ?? -1, 0.5, accuracy: 0.001)
    }

    func testRoundTripViewToContent() {
        // 视图点 → 内容区相对 → 回视图点（无 contentToView 部分，用 screen 侧验证）
        let viewP = CGPoint(x: 200, y: 300)
        let rel = CoordinateMapper.viewToContent(viewP,
                                                 frame: CGSize(width: 456, height: 972),
                                                 viewSize: CGSize(width: 400, height: 800),
                                                 contentInFrame: contentInFrame)
        XCTAssertNotNil(rel)
        XCTAssertEqual(rel?.x ?? -1, 0.5, accuracy: 0.001)
        // 内容区占帧 0.9712，顶部 0.0288
        // viewY=300 → draw=(12.35,0,375.31,800) → py=300/800=0.375 → ry=(0.375-0.0288)/0.9712 ≈ 0.3565
        XCTAssertEqual(rel?.y ?? -1, 0.3565, accuracy: 0.002)
    }

    func testContentToScreen() {
        let screen = CoordinateMapper.contentToScreen(CGPoint(x: 0.5, y: 0.5),
                                                      contentRect: CGRect(x: 420, y: 62, width: 456, height: 944))
        XCTAssertEqual(screen.x, 648, accuracy: 0.001)
        XCTAssertEqual(screen.y, 534, accuracy: 0.001)
    }
}
