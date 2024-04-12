//
//  KeychainHelper.swift
//  Casper
//
//  Created by Patrick Liao on 3/15/24.
//
import Foundation

class KeychainHelper {
    static func save(_ value: String, service: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Create the query for the Keychain
        var query = [String: Any]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service
        query[kSecAttrAccount as String] = account
        query[kSecValueData as String] = data
        
        // Delete any existing value
        SecItemDelete(query as CFDictionary)
        
        // Add the new value to the Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("Error saving to Keychain: \(status)")
            return
        }
    }
    
    static func load(service: String, account: String) -> String? {
        // Create the query for the Keychain
        var query = [String: Any]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service
        query[kSecAttrAccount as String] = account
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        // Perform the query to retrieve data from the Keychain
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            print("Error loading from Keychain: \(status)")
            return nil
        }
        
        // Convert the retrieved data to a string
        return String(data: data, encoding: .utf8)
    }
}
