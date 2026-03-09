import Foundation
import Testing
@testable import ClaudeMonitor

@MainActor
@Suite("SessionAliasStore Tests")
struct SessionAliasStoreTests {

    private func makeSut() -> (SessionAliasStore, UserDefaults) {
        let suiteName = "test.alias.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SessionAliasStore(defaults: defaults)
        return (store, defaults)
    }

    @Test("alias returns nil for unknown sessionId")
    func aliasReturnsNilForUnknown() {
        let (sut, _) = makeSut()
        #expect(sut.alias(for: "unknown-id") == nil)
    }

    @Test("setAlias stores and retrieves alias")
    func setAndGetAlias() {
        let (sut, _) = makeSut()
        sut.setAlias("기능개발", for: "123-ttys010")
        #expect(sut.alias(for: "123-ttys010") == "기능개발")
    }

    @Test("setAlias with empty string removes alias")
    func emptyStringRemovesAlias() {
        let (sut, _) = makeSut()
        sut.setAlias("리뷰용", for: "123-ttys010")
        sut.setAlias("", for: "123-ttys010")
        #expect(sut.alias(for: "123-ttys010") == nil)
    }

    @Test("setAlias with whitespace-only removes alias")
    func whitespaceOnlyRemovesAlias() {
        let (sut, _) = makeSut()
        sut.setAlias("테스트", for: "id-1")
        sut.setAlias("   ", for: "id-1")
        #expect(sut.alias(for: "id-1") == nil)
    }

    @Test("removeAlias deletes stored alias")
    func removeAlias() {
        let (sut, _) = makeSut()
        sut.setAlias("실험", for: "id-2")
        sut.removeAlias(for: "id-2")
        #expect(sut.alias(for: "id-2") == nil)
    }

    @Test("aliases persist across instances")
    func persistenceAcrossInstances() {
        let suiteName = "test.alias.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let store1 = SessionAliasStore(defaults: defaults)
        store1.setAlias("핫픽스", for: "pid-tty")

        let store2 = SessionAliasStore(defaults: defaults)
        #expect(store2.alias(for: "pid-tty") == "핫픽스")
    }

    @Test("setAlias truncates to 100 characters")
    func truncatesLongAlias() {
        let (sut, _) = makeSut()
        let longString = String(repeating: "가", count: 150)
        sut.setAlias(longString, for: "id-3")
        #expect(sut.alias(for: "id-3")!.count == 100)
    }

    @Test("setAlias filters control characters")
    func filtersControlCharacters() {
        let (sut, _) = makeSut()
        sut.setAlias("hello\tworld\ntest", for: "id-4")
        let result = sut.alias(for: "id-4")!
        #expect(!result.contains("\t"))
        #expect(!result.contains("\n"))
    }

    @Test("multiple aliases for different sessions")
    func multipleAliases() {
        let (sut, _) = makeSut()
        sut.setAlias("프론트", for: "id-a")
        sut.setAlias("백엔드", for: "id-b")
        #expect(sut.alias(for: "id-a") == "프론트")
        #expect(sut.alias(for: "id-b") == "백엔드")
        #expect(sut.aliases.count == 2)
    }
}
