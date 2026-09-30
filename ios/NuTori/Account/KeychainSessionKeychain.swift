import Foundation
import NuToriCore
import Security

nonisolated struct KeychainSessionKeychain: SessionKeychain {
    func sessionToken() async throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            // Security の API は CFTypeRef で返すので、キャストは避けられない
            guard let data = result as? Data else {
                throw KeychainError(status: errSecDecode)
            }
            return String(decoding: data, as: UTF8.self)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    func save(sessionToken: String) async throws {
        let data = Data(sessionToken.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var attributes = baseQuery
            attributes[kSecValueData as String] = data
            // 起動したあとの、ロック中のバックグラウンドの同期でも読めるようにする
            attributes[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus)
            }
        default:
            throw KeychainError(status: updateStatus)
        }
    }

    func deleteSessionToken() async throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    struct KeychainError: Error, Equatable {
        let status: OSStatus
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "app.nu-tori.session",
            kSecAttrAccount as String: "session-token",
        ]
    }
}
