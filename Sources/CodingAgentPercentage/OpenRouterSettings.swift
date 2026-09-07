import Foundation
import Security

/// Off-by-default opt-in for OpenRouter token/credit usage. Unlike Copilot, there's no existing local
/// sign-in to read — the user must paste their own API key, so it is stored in the Keychain, not UserDefaults.
@MainActor
final class OpenRouterSettings: ObservableObject {
    nonisolated static let enabledKey = "OpenRouterNetworkUsageEnabled"
    private nonisolated static let keychainService = "com.francois.vc-funding.openrouter"
    private nonisolated static let keychainAccount = "api-key"

    private let defaults: UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }
    @Published var apiKey: String {
        didSet {
            if apiKey.isEmpty {
                Self.deleteAPIKey()
            } else {
                Self.storeAPIKey(apiKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.apiKey = Self.readAPIKey() ?? ""
    }

    nonisolated static func hasStoredAPIKey() -> Bool {
        readAPIKey()?.isEmpty == false
    }

    nonisolated static func readAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated static func storeAPIKey(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let data = Data(key.utf8)
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private nonisolated static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
