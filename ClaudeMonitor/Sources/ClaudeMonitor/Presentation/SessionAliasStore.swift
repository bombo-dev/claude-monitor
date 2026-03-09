import Foundation

@MainActor
@Observable
final class SessionAliasStore {
    private let defaults: UserDefaults
    private let key = "sessionAliases"

    private(set) var aliases: [String: String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.aliases = Self.load(from: defaults, key: key)
    }

    func alias(for sessionId: String) -> String? {
        aliases[sessionId]
    }

    func setAlias(_ alias: String, for sessionId: String) {
        let sanitized = Self.sanitize(alias)
        if sanitized.isEmpty {
            aliases.removeValue(forKey: sessionId)
        } else {
            aliases[sessionId] = sanitized
        }
        save()
    }

    func removeAlias(for sessionId: String) {
        aliases.removeValue(forKey: sessionId)
        save()
    }

    // MARK: - Private

    private func save() {
        guard let data = try? JSONEncoder().encode(aliases) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [String: String] {
        guard let data = defaults.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    static func sanitize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        let result = String(String.UnicodeScalarView(filtered))
        return String(result.prefix(100))
    }
}
