//
//  TodoistTokenStore.swift
//  Daily Three
//
//  Keeps the Todoist API token in the Keychain on this device. It is never written to SwiftData or
//  CloudKit, so it doesn't sync into the database.
//

import Foundation
import Security

enum TodoistTokenStore {
    private static let service = "goodhouse.Daily-Three.todoist"
    private static let account = "api-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    static func save(_ token: String) throws {
        delete()
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TodoistError.network("The token couldn't be saved to the Keychain (error \(status)).")
        }
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
