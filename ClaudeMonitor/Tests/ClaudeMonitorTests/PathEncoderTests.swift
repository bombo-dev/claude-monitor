import Testing
import Foundation
@testable import ClaudeMonitor

@Suite("PathEncoder Tests")
struct PathEncoderTests {

    let encoder = PathEncoder(homeDirectory: URL(fileURLWithPath: "/tmp/test-home"))

    // MARK: - encode(path:)

    @Test("TC-01: 기본 변환")
    func encodeBasicPath() {
        #expect(encoder.encode(path: "/Users/bombo/foo") == "-Users-bombo-foo")
    }

    @Test("TC-02: 후행 슬래시 제거")
    func encodeTrailingSlash() {
        #expect(encoder.encode(path: "/Users/bombo/foo/") == "-Users-bombo-foo")
    }

    @Test("TC-03: .. 정규화")
    func encodeDoubleDot() {
        #expect(encoder.encode(path: "/Users/bombo/../bombo/foo") == "-Users-bombo-foo")
    }

    @Test("TC-04: . 정규화")
    func encodeSingleDot() {
        #expect(encoder.encode(path: "/Users/bombo/./foo") == "-Users-bombo-foo")
    }

    @Test("TC-05: 이중 슬래시 정규화")
    func encodeDoubleSlash() {
        #expect(encoder.encode(path: "/Users/bombo/foo//bar") == "-Users-bombo-foo-bar")
    }

    @Test("TC-06: 루트 경로")
    func encodeRootPath() {
        #expect(encoder.encode(path: "/") == "-")
    }

    @Test("TC-07: 다중 세그먼트")
    func encodeMultipleSegments() {
        #expect(encoder.encode(path: "/a/b/c/d/e") == "-a-b-c-d-e")
    }

    @Test("TC-08: 공백 포함 경로")
    func encodePathWithSpaces() {
        #expect(encoder.encode(path: "/Users/bombo/my project") == "-Users-bombo-my project")
    }

    // MARK: - projectDirectory(for:)

    @Test("TC-09: 기본 경로 조합")
    func projectDirectoryBasic() throws {
        let result = try #require(encoder.projectDirectory(for: "/Users/bombo/foo"))
        #expect(result.path().hasSuffix(".claude/projects/-Users-bombo-foo/"))
    }

    @Test("TC-10: 정규화 후 조합")
    func projectDirectoryNormalized() throws {
        let result = try #require(encoder.projectDirectory(for: "/Users/bombo/../bar"))
        #expect(result.path().hasSuffix(".claude/projects/-Users-bar/"))
    }

    @Test("TC-11: 순수 함수 - 동일 입력 동일 출력")
    func projectDirectoryPureFunction() {
        let first = encoder.projectDirectory(for: "/Users/bombo/foo")
        let second = encoder.projectDirectory(for: "/Users/bombo/foo")
        #expect(first == second)
    }
}
