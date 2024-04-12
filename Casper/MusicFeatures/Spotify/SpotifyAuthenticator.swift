//
//  SpotifyAuthenticator.swift
//  Casper
//
//  Created by Patrick Liao on 3/6/24.
//

// This file handles the authentication with Spotify using OAuth 2.0 with PKCE.
import AuthenticationServices
import CryptoKit
import Foundation

class SpotifyAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    // Client ID and Redirect URI from your Spotify Developer Dashboard
    private let clientId: String = "839b4f017b23430bbe78185f2e3e8f64"
    private let scopes: String = "user-modify-playback-state user-read-playback-state user-read-currently-playing playlist-modify-public playlist-modify-private user-top-read"
    private let codeVerifier: String
    private let codeChallenge: String
    private var accessToken: String?
    private var refreshToken: String?
    private var authorizationCode: String?
    let redirectUri = "Casper://callback"
    private var currentSession: ASWebAuthenticationSession?
    private let keychainService = "com.example.Casper.SpotifyAccessToken"

    override init() {
        self.codeVerifier = SpotifyAuthenticator.generateCodeVerifier()
        self.codeChallenge = SpotifyAuthenticator.generateCodeChallenge(verifier: self.codeVerifier)
    }

    // Method to save the access token to Keychain
    private func saveAccessTokenToKeychain(accessToken: String) {
        // Construct the query for saving the access token
        let accessQuery: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : "accessToken",
            kSecAttrService as String : keychainService,
            kSecValueData as String   : accessToken.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrAccessGroup as String: "com.CasperAI.casper"
        ]
        
        // Delete any existing access token item
        SecItemDelete(accessQuery as CFDictionary)
        
        // Add the new access token item to the keychain
        let accessStatus = SecItemAdd(accessQuery as CFDictionary, nil)
        
        // Check the result and handle errors
        if accessStatus != errSecSuccess {
            print("Error saving access token: \(accessStatus)")
        }
    }

    private func saveRefreshTokenToKeychain(refreshToken: String) {
        // Construct the query for saving the refresh token
        let refreshQuery: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : "refreshToken",
            kSecAttrService as String : keychainService,
            kSecValueData as String   : refreshToken.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrAccessGroup as String: "com.CasperAI.casper"
        ]
        
        // Delete any existing refresh token item
        SecItemDelete(refreshQuery as CFDictionary)
        
        // Add the new refresh token item to the keychain
        let refreshStatus = SecItemAdd(refreshQuery as CFDictionary, nil)
        
        // Check the result and handle errors
        if refreshStatus != errSecSuccess {
            print("Error saving refresh token: \(refreshStatus)")
        }
    }

    // Updated method to save both access token and refresh token to Keychain
    private func saveTokensToKeychain(accessToken: String, refreshToken: String) {
        saveAccessTokenToKeychain(accessToken: accessToken)
        saveRefreshTokenToKeychain(refreshToken: refreshToken)
    }
    // Method to load the access token from Keychain
    private func loadAccessTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "accessToken",
            kSecAttrService as String: keychainService,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func loadRefreshTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "refreshToken",
            kSecAttrService as String: keychainService,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    func authenticate(completion: @escaping (Bool, String?) -> Void) {
        print("Spotify service authenticating")
        
        // Check if there is an access token stored
        if let accessToken = loadAccessTokenFromKeychain() {
            // Verify if the loaded access token is still valid
            print ("found access token: \(accessToken)")
            validateAccessToken(accessToken: accessToken) { isValid in
                if isValid {
                    // Access token is still valid, return it
                    print("Access token is valid")
                    completion(true, accessToken)
                } else {
                    // Access token has expired, attempt to refresh it
                    print("Access token has expired. Refreshing...")
                    self.refreshAccessToken { success in
                        completion(success, self.accessToken)
                    }
                }
            }
        } else {
            // No access token found, start a new authentication flow
            print("No token found. Starting authentication flow...")
            startAuthenticationFlow { success, code in
                if success, let authorizationCode = code {
                    // Request access token using the authorization code
                    self.requestAccessToken(authorizationCode: authorizationCode) { success, accessToken, _ in
                        if success, let accessToken = accessToken {
                            // Authentication successful, save the access token
                            self.saveAccessTokenToKeychain(accessToken: accessToken)
                            completion(true, accessToken)
                        } else {
                            // Authentication failed
                            completion(false, nil)
                        }
                    }
                } else {
                    // Authentication flow failed
                    completion(false, nil)
                }
            }
        }
        
    }



    private func validateAccessToken(accessToken: String, completion: @escaping (Bool) -> Void) {
        // Make a simple request to the Spotify API to validate the token
        let validationURL = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: validationURL)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { _, response, error in
            guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                completion(false)
                return
            }
            // If the status code is 200, the token is valid
            completion(httpResponse.statusCode == 200)
        }.resume()
    }

    private func startAuthenticationFlow(completion: @escaping (Bool, String?) -> Void) {
        func openWebAuthenticationSession() {
            let authorizationEndpoint = "https://accounts.spotify.com/authorize"
            let scheme = "Casper"
            
            // Construct the full authorization URL
            guard let authURL = URL(string: "\(authorizationEndpoint)?client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri)&scope=\(scopes)&code_challenge_method=S256&code_challenge=\(codeChallenge)") else {
                completion(false, "Invalid authorization URL.")
                return
            }

            // Start the web authentication session
            currentSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { [weak self] callbackURL, error in
                // Handle the authentication response
                if let error = error {
                    print ("weird error")
                    completion(false, error.localizedDescription)
                } else if let callbackURL = callbackURL, let code = URLComponents(string: callbackURL.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value {
                    completion(true, code)
                } else {
                    completion(false, "Unexpected error during authentication.")
                }
                self?.currentSession = nil
            }
            print ("session opened")
            currentSession?.presentationContextProvider = self
            currentSession?.start()
        }
        
        openWebAuthenticationSession()
    }

    private func requestAccessToken(authorizationCode: String, completion: @escaping (Bool, String?, String?) -> Void) {
        print("Requesting access token...")
        let codeVerifier = self.codeVerifier
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let bodyParameters = [
            "client_id": clientId,
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "redirect_uri": redirectUri,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = bodyParameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false, nil, nil)
                return
            }

            if let error = error {
                print("Request error: \(error.localizedDescription)")
                completion(false, nil, nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
                completion(false, nil, nil)
                return
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                let newAccessToken = tokenResponse.accessToken
                let newRefreshToken = tokenResponse.refreshToken
                
                self.accessToken = newAccessToken
                if let newRefreshToken = newRefreshToken {
                    self.refreshToken = newRefreshToken
                }
                
                self.saveTokensToKeychain(accessToken: newAccessToken, refreshToken: newRefreshToken ?? "")
                completion(true, newAccessToken, newRefreshToken)
            } catch {
                print("Failed to decode token response with error: \(error)")
                completion(false, nil, nil)
            }
        }.resume()
    }

    // Function to refresh the access token
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = loadRefreshTokenFromKeychain() else {
            print("Error: Refresh token is unavailable.")
            completion(false)
            return
        }

        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"

        let bodyParameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]

        request.httpBody = bodyParameters
            .map { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                print("Error: Self is deallocated.")
                completion(false)
                return
            }

            if let error = error {
                print("Error during token refresh: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                print("Token refresh failed with status code: \(String(describing: response as? HTTPURLResponse))")
                completion(false)
                return
            }

            do {
                let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                self.accessToken = tokenResponse.accessToken
                
                // Check if a new refresh token is provided in the response
                if let newRefreshToken = tokenResponse.refreshToken {
                    self.refreshToken = newRefreshToken
                    // Save both the new access token and new refresh token
                    self.saveTokensToKeychain(accessToken: tokenResponse.accessToken, refreshToken: newRefreshToken)
                } else {
                    // Only the access token is refreshed; no new refresh token provided
                    self.saveAccessTokenToKeychain(accessToken: tokenResponse.accessToken)
                }
                
                completion(true)
            } catch {
                print("Failed to decode refresh token response: \(error)")
                completion(false)
            }
        }.resume()
    }


    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    static func generateCodeChallenge(verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let keyWindow = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        } else {
            // If no key window is found, return the main window as a fallback
            return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        }
    }

}

struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
