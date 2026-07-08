import Foundation
import Security

/// Stores auth tokens under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// (PLAN.md §5) — never in UserDefaults, never synced to iCloud Keychain,
/// unreadable before the device's first unlock after a reboot.
enum KeychainService {
    private static let service = "com.fittrack.app.auth"

    static func set(_ data: Data, for key: String) {
        var query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    static func setString(_ value: String, for key: String) {
        set(Data(value.utf8), for: key)
    }

    static func getString(_ key: String) -> String? {
        get(key).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
