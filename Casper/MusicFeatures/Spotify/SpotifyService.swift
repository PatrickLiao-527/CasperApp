//
//  SpotifyService.swift
//  Casper
//
//  Created by Patrick Liao on 3/6/24.
//

// This file handles the specific interaction with the spotify api
import Foundation
import os


class SpotifyService: ObservableObject {
    private var accessToken: String?
    private let spotifyAuthenticator = SpotifyAuthenticator()
    private var appStateManager: AppStateManager
    private var alreadyInit = false
    init(appStateManager: AppStateManager) {
        print ("spotify initialization called -------------------")
        self.appStateManager = appStateManager
        print ("already init is \(alreadyInit)")
        self.alreadyInit = true
        if !alreadyInit{
            authenticateIfNeeded { isAuthenticated in
                if isAuthenticated {
                    print("Successfully authenticated with Spotify.")
                    // Further actions upon successful authentication can be placed here
                } else {
                    print("Failed to authenticate with Spotify.")
                    // Handle authentication failure
                }
                
            }
        }
    }
    
    func authenticateIfNeeded(completion: @escaping (Bool) -> Void) {
        spotifyAuthenticator.authenticate{ [weak self] success, token in
            guard let self = self, success, let token = token else {
                completion(false)
                return
            }
            self.accessToken = token
            completion(true)
        }
    }
//    func searchForSong(with song: Song, completion: @escaping ([String]) -> Void) {
//        guard let accessToken = self.accessToken else {
//            print("Error: Access token is not available.")
//            completion([])
//            return
//        }
//
//        let query = "\(song.title) \(song.artist)"
//        print ("query: \(query)")
//        let queryParams = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
//        let urlString = "https://api.spotify.com/v1/search?type=track&limit=1&q=\(queryParams)"
//        guard let url = URL(string: urlString) else {
//            print("Error: Failed to construct search URL for query: \(query)")
//            completion([])
//            return
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "GET"
//        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Network request error for query \(query): \(error.localizedDescription)")
//                completion([])
//                return
//            }
//
//            guard let data = data else {
//                print("Error: No data received from the search request for query \(query).")
//                completion([])
//                return
//            }
//
//            do {
//                let searchResults = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
//                if let trackItem = searchResults.tracks.items.first {
//                    let foundSong = Song(title: trackItem.name, artist: trackItem.artists.first?.name ?? "Unknown Artist", uri: trackItem.uri)
//                    print ("URI: \(foundSong.uri)")
//                    completion([foundSong.uri])
//                } else {
//                    print("No track found for query \(query).")
//                    completion([])
//                }
//            } catch {
//                print("Failed to decode response for query \(query): \(error)")
//                completion([])
//            }
//        }.resume()
//    }
    func playSong(userInput: String, completion: @escaping (Bool, String?) -> Void) {
        guard let accessToken = self.accessToken else {
            let errorMessage = "Error: Access token is not available."
            print(errorMessage)
            completion(false, errorMessage)
            return
        }
        
        // First, fetch available devices
        self.fetchAvailableDevices(accessToken: accessToken) { devices, error in
            guard let devices = devices, !devices.isEmpty else {
                let errorMessage = error ?? "No available devices found or failed to fetch devices."
                print(errorMessage)
                completion(false, errorMessage) // Indicate failure
                return
            }
            
            // Check for a Mac device or use the first available device
            guard let macDevice = devices.first(where: { $0.name.contains("Mac") }) else {
                let errorMessage = "No Mac device found. Prompting user to open Spotify."
                print(errorMessage)
                completion(false, errorMessage) // Indicate that no Mac device was found
                return
            }
            
            // Transfer playback if the Mac device isn't active, then execute playback request
            if !macDevice.isActive {
                self.transferUserPlayback(to: macDevice.id, accessToken: accessToken) { success, error in
                    if success {
                        // After successfully transferring playback, execute playback request
                        self.playSongsFromSuggestion(userInput: userInput) { success, errorMessage in
                            completion(success, errorMessage) // Pass the success status and error message up the chain
                        }
                    } else {
                        let errorMessage = error ?? "Failed to transfer user playback."
                        completion(false, errorMessage) // Handle the error
                    }
                }
            } else {
                // Execute playback request directly if the Mac device is already active
                self.playSongsFromSuggestion(userInput: userInput) { success, errorMessage in
                    completion(success, errorMessage) // Pass the success status and error message up the chain
                }
            }
        }
    }
    func playSongsFromSuggestion(userInput: String, completion: @escaping (Bool, String?) -> Void) {
        fetchSongSuggestions(userInput: userInput) { [weak self] trackIds, songGenre,  error in
            guard let self = self else {
                completion(false, "Internal error: self is nil.")
                return
            }
            
            if let error = error {
                self.appStateManager.updateSystemMessage(error)
                completion(false, error)
                return
            }
            
            guard let trackIds = trackIds, !trackIds.isEmpty else {
                let errorMessage = "No songs found for the given suggestions."
                self.appStateManager.updateSystemMessage(errorMessage)
                completion(false, errorMessage)
                return
            }
            
            self.getUserSpotifyId { userId in
                guard let userId = userId else {
                    let errorMessage = "Error retrieving user ID from Spotify."
                    self.appStateManager.updateSystemMessage(errorMessage)
                    completion(false, errorMessage)
                    return
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM dd"
                let formattedDate = formatter.string(from: Date())
                let playlistName = "Casper's curated playlist for \(songGenre!) musics on \(formattedDate)"

                
                self.createPlaylist(for: userId, with: playlistName, userInput: userInput) { playlistId in
                    guard let playlistId = playlistId else {
                        let errorMessage = "Error creating a new playlist."
                        self.appStateManager.updateSystemMessage(errorMessage)
                        completion(false, errorMessage)
                        return
                    }
                    
                    var trackURIs: [String] = []
                    let group = DispatchGroup()
                    for trackId in trackIds {
                        group.enter()
                        self.fetchTrackURI(trackID: trackId.uri) { uri, error in
                            if let uri = uri {
                                trackURIs.append(uri)
                            } else if let error = error {
                                print("Error fetching URI for track ID \(trackId): \(error)")
                            }
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        guard !trackURIs.isEmpty else {
                            let errorMessage = "No track URIs found for the suggested songs."
                            self.appStateManager.updateSystemMessage(errorMessage)
                            completion(false, errorMessage)
                            return
                        }
                        
                        self.addTracksToPlaylist(playlistId: playlistId, trackURIs: trackURIs) { success in
                            if success {
                                let message = "Attempting to start playback..."
                                self.appStateManager.updateSystemMessage(message)
                                self.startPlaylistPlayback(playlistId: playlistId, completion: { success in
                                    completion(success, success ? nil : "Failed to start playlist playback.")
                                })
                            } else {
                                let errorMessage = "Failed to add tracks to the playlist."
                                self.appStateManager.updateSystemMessage(errorMessage)
                                completion(false, errorMessage)
                            }
                        }
                    }
                }
            }
        }
    }
    private func startPlaylistPlayback(playlistId: String, completion: @escaping (Bool) -> Void) {
        guard let accessToken = self.accessToken else {
            print("Error: Access token is not available.")
            completion(false)
            return
        }
        
        // Assuming the user's device is already active or has been set elsewhere
        let playEndpoint = "https://api.spotify.com/v1/me/player/play"
        guard let url = URL(string: playEndpoint) else {
            print("Error: Failed to construct the play endpoint URL.")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // The body of the request sets the context to the playlist URI
        let body: [String: Any] = ["context_uri": "spotify:playlist:\(playlistId)"]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Error: Failed to serialize request body.")
            completion(false)
            return
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Perform the request to start playback
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
                print("Error starting playlist playback: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            print("Playback of the playlist started successfully.")
            DispatchQueue.main.async{
                completion(true)
            }
        }
        
        task.resume()
    }
    func createPlaylist(for userId: String, with name: String, userInput: String, completion: @escaping (String?) -> Void) {
        guard let accessToken = self.accessToken else {
            print("Access token is not available.")
            completion(nil)
            return
        }
        
        let endpoint = "https://api.spotify.com/v1/users/\(userId)/playlists"
        guard let url = URL(string: endpoint) else {
            print("Failed to construct the playlist creation URL.")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "description": "Playlist created by Casper for \"\(userInput)\"",
            "public": false // Change this as per requirement
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Failed to serialize the request body.")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil, let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 201 else {
                print("Failed to create playlist. Error: \(response.debugDescription)")
                completion(nil)
                return
            }
            
            do {
                if let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let playlistId = result["id"] as? String {
                    completion(playlistId)
                } else {
                    completion(nil)
                }
            } catch {
                print("Error parsing the response data.")
                completion(nil)
            }
        }
        task.resume()
    }
    func addTracksToPlaylist(playlistId: String, trackURIs: [String], completion: @escaping (Bool) -> Void) {
        guard !trackURIs.isEmpty else {
            print("No track URIs provided.")
            completion(false)
            return
        }
        
        guard let accessToken = self.accessToken else {
            print("Access token is not available.")
            completion(false)
            return
        }
        
        let endpoint = "https://api.spotify.com/v1/playlists/\(playlistId)/tracks"
        guard let url = URL(string: endpoint) else {
            print("Failed to construct the URL for adding tracks.")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["uris": trackURIs]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Failed to serialize the request body.")
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            print ("error in adding tracks : \(response.debugDescription)")
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
                print("Failed to add tracks to the playlist.")
                completion(false)
                return
            }
            
            completion(true)
        }
        task.resume()
    }
    func fetchAvailableDevices(accessToken: String, completion: @escaping ([Device]?, String?) -> Void) {
        let url = URL(string: "https://api.spotify.com/v1/me/player/devices")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching devices: \(error.localizedDescription)")
                completion(nil, "Failed to fetch devices: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("No response from server.")
                completion(nil, "No response from server.")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("Error fetching devices: HTTP status code \(httpResponse.statusCode)")
                completion(nil, "Failed to fetch devices: HTTP status code \(httpResponse.statusCode)")
                return
            }
            
            // Print the full response if there's data
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("API Response: \(responseString)")
            } else {
                print("No data received.")
                completion(nil, "No data received from Spotify.")
                return
            }
            
            // Attempt to decode the data into the DevicesResponse struct
            do {
                let decoder = JSONDecoder()
                let devicesResponse = try decoder.decode(DevicesResponse.self, from: data!)
                print("Found devices: \(devicesResponse.devices)")
                completion(devicesResponse.devices, nil)
            } catch {
                print("Failed to decode devices: \(error.localizedDescription)")
                completion(nil, "Failed to decode device list: \(error.localizedDescription)")
            }
        }.resume()
    }
    private func executePlaybackRequest(to playEndpoint: String, song: Song, accessToken: String, completion: @escaping (Bool) -> Void) {
        print ("attempting to play song: \(song)")
        guard let url = URL(string: playEndpoint) else {
            print("Error: Failed to construct the play endpoint URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Construct the request body with the song's URI
        let requestBody: [String: Any] = ["uris": [song.uri]]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("Error: Failed to serialize request body.")
            return
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Perform the network request to start playback
        URLSession.shared.dataTask(with: request) { data, response, error in
            print (requestBody)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
                // Check for errors or unexpected status codes
                print("Error: Failed to start playback. StatusCode: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                if let error = error {
                    completion(false) // Indicate failure
                    print("Network Error: \(error.localizedDescription)")
                }
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    
                    completion(false) // Indicate failure
                    print("Spotify Response: \(responseBody)")
                }
                return
            }
            // Successfully started playback
            completion(true) // Indicate success
            print("Playback started successfully for \(song.title) by \(song.artist).")
        }.resume()
    }
    private func transferUserPlayback(to deviceId: String, accessToken: String, completion: @escaping (Bool, String?) -> Void) {
        print("Transferring user playback")
        let transferEndpoint = "https://api.spotify.com/v1/me/player"
        guard let url = URL(string: transferEndpoint) else {
            print("Error: Failed to construct the transfer endpoint URL.")
            completion(false, "Failed to construct the transfer endpoint URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Construct the request body to transfer playback
        let requestBody: [String: Any] = ["device_ids": [deviceId], "play": false]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("Error: Failed to serialize transfer request body.")
            completion(false, "Failed to serialize transfer request body.")
            return
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Perform the network request to transfer playback
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: No response from server.")
                completion(false, "No response from server.")
                return
            }
            if httpResponse.statusCode == 204 {
                print("Successfully transferred playback to mac.")
                completion(true, nil)
            } else {
                print("Error: Failed to transfer playback. StatusCode: \(httpResponse.statusCode)")
                completion(false, "Failed to transfer playback with status code \(httpResponse.statusCode).")
            }
        }.resume()
    }
    enum FetchError: Error {
        case accessTokenUnavailable
        case networkError(Error)
        case serverError(statusCode: Int)
        case dataUnavailable
        case decodingError
        case unknownError
    }
    func fetchTrackURI(trackID: String, completion: @escaping (String?, FetchError?) -> Void) {
        guard let accessToken = self.accessToken else {
            print("Access token is not available.")
            completion(nil, .accessTokenUnavailable)
            return
        }
        
        let url = URL(string: "https://api.spotify.com/v1/tracks/\(trackID)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, .networkError(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(nil, .serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0))
                return
            }
            
            guard let data = data else {
                completion(nil, .dataUnavailable)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let trackURI = json?["uri"] as? String {
                    completion(trackURI, nil)
                } else {
                    completion(nil, .decodingError)
                }
            } catch {
                completion(nil, .decodingError)
            }
        }.resume()
    }
    func fetchSongSuggestions(userInput: String, completion: @escaping ([Song]?, String?, String?) -> Void) {
        // Directly fetch recommendations without pre-checking for LLM Parameters.
        getRecommendations(userInput: userInput) { result, songGenre in
            switch result {
            case .success(let trackObjects):
                  let songsWithURIs: [Song] = trackObjects.compactMap { trackObject in
                      guard let trackID = trackObject.id else { return nil }
                      return Song(title: "", artist: "", uri: trackID)
                  }
                
                DispatchQueue.main.async {
                    completion(songsWithURIs, songGenre, nil)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(nil, "", "Failed to fetch song recommendations: \(error.localizedDescription)")
                }
            }
        }
    }
    func getUserSpotifyId(completion: @escaping (String?) -> Void) {
        guard let accessToken = self.accessToken else {
            print("Access token is not available.")
            completion(nil)
            return
        }
        
        let url = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to fetch user data: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let userId = json["id"] as? String {
                    completion(userId)
                } else {
                    print("User ID not found in the response.")
                    completion(nil)
                }
            } catch {
                print("Failed to decode the response: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
//    func getTopArtistsWithIDs(completion: @escaping (Result<[String], Error>) -> Void) {
//        guard let accessToken = self.accessToken else {
//            completion(.failure(SpotifyServiceError.accessTokenUnavailable))
//            return
//        }
//
//        let topArtistsURL = URL(string: "https://api.spotify.com/v1/me/top/artists?limit=50")! // Increase limit to get a broader selection
//        var request = URLRequest(url: topArtistsURL)
//        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
//        request.httpMethod = "GET"
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//                return
//            }
//
//            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
//                DispatchQueue.main.async {
//                    completion(.failure(SpotifyServiceError.unexpectedResponse))
//                }
//                return
//            }
//
//            guard let data = data else {
//                DispatchQueue.main.async {
//                    completion(.failure(SpotifyServiceError.noDataReceived))
//                }
//                return
//            }
//
//            do {
//                let decoder = JSONDecoder()
//                let topArtistsResponse = try decoder.decode(TopArtistsResponse.self, from: data)
//                // Order the artists by popularity in descending order and take the top two
//                let sortedArtistIDs = topArtistsResponse.items
//                    .sorted(by: { ($0.popularity ?? 0) > ($1.popularity ?? 0) })
//                    .map { $0.id }
//                    .prefix(4)
//
//                DispatchQueue.main.async {
//                    completion(.success(Array(sortedArtistIDs)))
//                }
//
//            } catch {
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//            }
//        }.resume()
//    }
//    struct TopTracksResponse: Decodable { //MARK: Not used but might be useful
//        let items: [TrackItem]
//    }
//    struct TrackItem: Codable {
//        let id: String
//    }
//    func getTopTracksWithIDs(completion: @escaping (Result<[String], Error>) -> Void) {
//        guard let accessToken = self.accessToken else {
//            completion(.failure(SpotifyServiceError.accessTokenUnavailable))
//            return
//        }
//
//        let topTracksURL = URL(string: "https://api.spotify.com/v1/me/top/tracks")! // Requesting top tracks without specifying limit
//        var request = URLRequest(url: topTracksURL)
//        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
//        request.httpMethod = "GET"
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//                return
//            }
//
//            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
//                DispatchQueue.main.async {
//                    completion(.failure(SpotifyServiceError.unexpectedResponse))
//                }
//                return
//            }
//
//            guard let data = data else {
//                DispatchQueue.main.async {
//                    completion(.failure(SpotifyServiceError.noDataReceived))
//                }
//                return
//            }
//
//            do {
//                let decoder = JSONDecoder()
//                let topTracksResponse = try decoder.decode(TopTracksResponse.self, from: data)
//                var trackIDs = topTracksResponse.items.map { $0.id }
//                // Shuffle the array and then take the first two elements.
//                trackIDs.shuffle()
//                let selectedIDs = Array(trackIDs.prefix(0))
//                DispatchQueue.main.async {
//                    completion(.success(selectedIDs))
//                }
//
//            } catch {
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//            }
//        }.resume()
//    }
    func getTopArtistsWithDetails(completion: @escaping (Result<[(name: String, genres: [String]?)], Error>) -> Void) {
        guard let accessToken = self.accessToken else {
            completion(.failure(SpotifyServiceError.accessTokenUnavailable))
            return
        }
        
        let topArtistsURL = URL(string: "https://api.spotify.com/v1/me/top/artists?limit=40")! //MARK: Change limit number for testing purposes
        var request = URLRequest(url: topArtistsURL)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(.failure(SpotifyServiceError.unexpectedResponse))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(SpotifyServiceError.noDataReceived))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let topArtistsResponse = try decoder.decode(TopArtistsResponse.self, from: data)
                var artistDetails = topArtistsResponse.items.map { artist in
                    (name: artist.name, genres: artist.genres)
                }
                
//                // Add additional hardcoded artists from various genres
//                let additionalArtists: [(name: String, genres: [String]?)] = [
//                    // Classical
//                    (name: "Ludwig van Beethoven", genres: ["classical"]),
//                    (name: "Johann Sebastian Bach", genres: ["classical", "baroque"]),
//
//                    // Jazz
//                    (name: "Miles Davis", genres: ["jazz", "bebop"]),
//                    (name: "Ella Fitzgerald", genres: ["jazz", "vocal jazz"]),
//
//                    // Rock
//                    (name: "The Beatles", genres: ["rock", "british invasion"]),
//                    (name: "Led Zeppelin", genres: ["rock", "classic rock"]),
//
//                    // Hip-Hop
//                    (name: "Tupac Shakur", genres: ["hip hop", "west coast rap"]),
//                    (name: "The Notorious B.I.G.", genres: ["hip hop", "east coast rap"]),
//
//                    // Electronic
//                    (name: "Daft Punk", genres: ["electronic", "house"]),
//                    (name: "Deadmau5", genres: ["electronic", "progressive house"]),
//
//                    // Country
//                    (name: "Johnny Cash", genres: ["country", "classic country"]),
//                    (name: "Dolly Parton", genres: ["country"]),
//
//                    // R&B/Soul
//                    (name: "Aretha Franklin", genres: ["soul", "r&b"]),
//                    (name: "Stevie Wonder", genres: ["soul", "funk", "r&b"]),
//
//                    // Pop
//                    (name: "Madonna", genres: ["pop"]),
//                    (name: "Michael Jackson", genres: ["pop", "soul"]),
//
//                    // Metal
//                    (name: "Metallica", genres: ["metal", "thrash metal"]),
//                    (name: "Iron Maiden", genres: ["metal", "heavy metal"]),
//
//                    // Reggae
//                    (name: "Bob Marley", genres: ["reggae"]),
//                    (name: "Peter Tosh", genres: ["reggae"]),
//
//                    // Ambient
//                    (name: "Brian Eno", genres: ["ambient", "experimental"]),
//                    (name: "Aphex Twin", genres: ["ambient", "electronic"]),
//
//                    // Blues
//                    (name: "B.B. King", genres: ["blues"]),
//                    (name: "Muddy Waters", genres: ["blues", "chicago blues"]),
//
//                    // Folk
//                    (name: "Bob Dylan", genres: ["folk", "singer-songwriter"]),
//                    (name: "Joan Baez", genres: ["folk", "folk rock"]),
//
//                    // Alternative
//                    (name: "Radiohead", genres: ["alternative rock", "art rock"]),
//                    (name: "The Smiths", genres: ["alternative rock", "indie rock"])
//                ]//MARK: Some hard coded artist to make the user's artist seed choice more comprehensive

                
                // Combine the user's top artists with the additional ones
                //artistDetails += additionalArtists
                
                DispatchQueue.main.async {
                    completion(.success(artistDetails))
                }
            } catch {
                    DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // Helper structs to decode the JSON response
    struct SearchResponse: Decodable {
        let artists: ArtistsResponse
    }
    struct ArtistsResponse: Decodable {
        let items: [ArtistItem]
    }
    struct ArtistItem: Decodable {
        let id: String
        let name: String
        // Include other fields as needed
    }
    func findArtistIdsByNames(artistNames: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        guard let accessToken = self.accessToken else {
            completion(.failure(SpotifyServiceError.accessTokenUnavailable))
            return
        }

        var artistIDs: [String] = []
        let group = DispatchGroup()

        for artistName in artistNames {
            group.enter()

            let searchQuery = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let searchURLString = "https://api.spotify.com/v1/search?q=\(searchQuery)&type=artist&limit=1"

            guard let searchURL = URL(string: searchURLString) else {
                completion(.failure(SpotifyServiceError.invalidURL))
                return
            }

            var request = URLRequest(url: searchURL)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "GET"

            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { group.leave() }

                if let error = error {
                    print("Error searching for artist \(artistName): \(error.localizedDescription)")
                    // Decide how to handle individual errors; for now, we'll just log and ignore.
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
                    print("Unexpected response or no data for artist \(artistName)")
                    // Same as above, handle how you wish
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let searchResponse = try decoder.decode(SearchResponse.self, from: data)
                    if let artistId = searchResponse.artists.items.first?.id {
                        artistIDs.append(artistId)
                    } else {
                        print("No artist found for \(artistName)")
                        // Handle case where artist isn't found
                    }
                } catch {
                    print("Error decoding response for artist \(artistName): \(error)")
                    // Handle decoding error
                }
            }.resume()
        }

        group.notify(queue: .main) {
            if artistIDs.isEmpty {
                completion(.failure(SpotifyServiceError.artistNotFound))
            } else {
                completion(.success(artistIDs))
            }
        }
    }
    func getRecommendations(userInput: String, completion: @escaping (Result<[TrackObject], Error>, String?) -> Void) {
        // Step 1: Fetch top artists with details
        getTopArtistsWithDetails { [weak self] result in
            switch result {
            case .success(let artistsDetails):
                // Step 2: Use artist details and user input to prompt the LLM
                self?.fetchLLMResponse(userInput: userInput, topArtists: artistsDetails) { llmResponse in
                    guard let llmParams = llmResponse else {
                        completion(.failure(SongFetchError.llmResponseError), "")
                        return
                    }
                    
                    // Step 3: Translate recommended artist names from LLM into Spotify IDs
                    self?.findArtistIdsByNames(artistNames: llmParams.recommendedArtists) { idsResult in
                        switch idsResult {
                        case .success(let artistIDs):
                            // Step 4: Use artist IDs and LLM parameters to fetch Spotify recommendations
                            self?.fetchSpotifyRecommendations(artistIDs: artistIDs, llmParams: llmParams, completion: completion)
                        case .failure(let error):
                            completion(.failure(error), "")
                        }
                    }
                }
            case .failure(let error):
                completion(.failure(error), "")
            }
        }
    }

    // Helper function to fetch Spotify recommendations using artist IDs and LLM parameters
    func fetchSpotifyRecommendations(artistIDs: [String], llmParams: RecommendationParameters, completion: @escaping (Result<[TrackObject], Error>, String?) -> Void) {
        guard let accessToken = self.accessToken else {
            completion(.failure(SongFetchError.tokenUnavailable), "")
            return
        }

        var components = URLComponents(string: "https://api.spotify.com/v1/recommendations")!
        components.queryItems = [
            URLQueryItem(name: "seed_artists", value: artistIDs.joined(separator: ",")),
            URLQueryItem(name: "seed_genres", value: llmParams.genre),
            URLQueryItem(name: "min_acousticness", value: "\(llmParams.min_acousticness)"),
            URLQueryItem(name: "max_acousticness", value: "\(llmParams.max_acousticness)"),
            URLQueryItem(name: "min_energy", value: "\(llmParams.min_energy)"),
            URLQueryItem(name: "max_energy", value: "\(llmParams.max_energy)"),
            URLQueryItem(name: "min_instrumentalness", value: "\(llmParams.min_instrumentalness)"),
            URLQueryItem(name: "max_instrumentalness", value: "\(llmParams.max_instrumentalness)"),
            URLQueryItem(name: "min_danceability", value: "\(llmParams.min_danceability)"),
            URLQueryItem(name: "max_danceability", value: "\(llmParams.max_danceability)"),
            URLQueryItem(name: "min_tempo", value: "\(llmParams.min_tempo)"),
            URLQueryItem(name: "max_tempo", value: "\(llmParams.max_tempo)")
        ]

        guard let url = components.url else {
            completion(.failure(SongFetchError.invalidURL), "")
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(SongFetchError.networkError(error)), "")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(SongFetchError.responseError("Spotify API returned non-200 response")),"")
                return
            }

            guard let data = data else {
                completion(.failure(SongFetchError.noData), "")
                return
            }

            do {
                let decoder = JSONDecoder()
                let spotifyTrackResponse = try decoder.decode(SpotifyTrackResponse.self, from: data)
                print("Received Spotify Tracks: \(spotifyTrackResponse.tracks)")
                completion(.success(spotifyTrackResponse.tracks), llmParams.genre)
            } catch {
                completion(.failure(error), "")
            }
        }.resume()
    }
    struct LLMResponse: Decodable {
        let response: Response
        var artists: [String]

        struct Response: Decodable {
            var genre: String
            var acousticness: [Float]
            var energy: [Float]
            var instrumentalness: [Float]
            var danceability: [Float]
            var tempo: [Float]
        }
        
        // Custom init from Decoder to handle the unique structure of "aritsts"
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            response = try container.decode(Response.self, forKey: .response)
            let artistsString = try container.decode(String.self, forKey: .artists)
            
            // Assuming the artists string is always formatted as "Output: ['Artist1', 'Artist2', ...]"
            // Extracting artist names from the string
            let artistsOutput = artistsString
                .replacingOccurrences(of: "Output: ", with: "")  // Remove the "Output: " prefix
                .trimmingCharacters(in: CharacterSet(["[", "]"]))  // Remove square brackets
                .split(separator: ",")  // Split by comma
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(["'", "\""])) }  // Trim spaces and quotes
            
            artists = artistsOutput
        }
        
        enum CodingKeys: String, CodingKey {
            case response
            case artists = "artists"
        }
    }


    func fetchLLMResponse(userInput: String,
                          topArtists: [(name: String, genres: [String]?)],
                          attempt: Int = 1,
                          maxAttempts: Int = 10,
                          completion: @escaping (RecommendationParameters?) -> Void) {
        let url = URL(string: "https://casper-backend-ea807e73fccc.herokuapp.com/api/suggest-song/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "user_input": userInput,
            "artists": [
                "items": topArtists.map { artist in
                    ["name": artist.name, "genres": artist.genres ?? []]
                }
            ]
        ]
        do { //MARK: Code for debugging
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Request Body in JSON format:\n\(jsonString)")
            }
        } catch {
            print("Error serializing JSON: \(error)")
        }


        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("Error serializing request body")
            completion(nil)
            return
        }
        
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if error != nil {
                print("Network request error:")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received from LLM.")
                completion(nil)
                return
            }
            
            if let rawJSONString = String(data: data, encoding: .utf8) {
                print("Raw LLM response JSON: \(rawJSONString)")
            }
            func addNoise(value: Float, noiseRange: Float, minValue: Float = 0, maxValue: Float = 1) -> Float {
                let noise = Float.random(in: -noiseRange...noiseRange)
                let noisyValue = value + noise
                return min(maxValue, max(minValue, noisyValue))
            }
            
            do {
                let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
                print("LLM response received and decoded successfully.")
                let responseContent = llmResponse.response
                // Create and populate the RecommendationParameters object with noise added
                let noiseRange: Float = 0
                let recommendationParams = RecommendationParameters(
                    genre: responseContent.genre,
                    min_acousticness: addNoise(value: responseContent.acousticness.first!, noiseRange: noiseRange).rounded(.down),
                    max_acousticness: addNoise(value: responseContent.acousticness.last!, noiseRange: noiseRange).rounded(.up),
                    min_energy: addNoise(value: responseContent.energy.first!, noiseRange: noiseRange).rounded(.down),
                    max_energy: addNoise(value: responseContent.energy.last!, noiseRange: noiseRange).rounded(.up),
                    min_instrumentalness: addNoise(value: responseContent.instrumentalness.first!,noiseRange: noiseRange).rounded(.down),
                    max_instrumentalness: addNoise(value: responseContent.instrumentalness.last!, noiseRange: noiseRange).rounded(.up),
                    min_danceability: addNoise(value: responseContent.danceability.first!, noiseRange: noiseRange).rounded(.down),
                    max_danceability: addNoise(value: responseContent.danceability.last!, noiseRange: noiseRange).rounded(.up),
                    min_tempo: addNoise(value: responseContent.tempo.first!, noiseRange: noiseRange*50.0, minValue: -.infinity, maxValue: .infinity).rounded(.down),
                    max_tempo: addNoise(value: responseContent.tempo.last!, noiseRange: noiseRange*50.0, minValue: -.infinity, maxValue: .infinity).rounded(.up),
                    recommendedArtists: llmResponse.artists
                )
                completion(recommendationParams)
            } catch {
                print("Error decoding LLM response: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    print("Retry attempt \(attempt) of \(maxAttempts)")
                    // Retry with a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        self.fetchLLMResponse(userInput: userInput, topArtists: topArtists, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                    }
                } else {
                    print("Max retry attempts reached. Unable to decode LLM response.")
                    completion(nil)
                }
            }
        }.resume()
    }



        
        
}

    
struct RecommendationParameters {
    var genre: String
    var min_acousticness: Float
    var max_acousticness: Float
    var min_energy: Float
    var max_energy: Float
    var min_instrumentalness: Float
    var max_instrumentalness: Float
    var min_danceability: Float
    var max_danceability: Float
    var min_tempo: Float
    var max_tempo: Float
    var recommendedArtists: [String]
}
    
struct DevicesResponse: Codable {
    let devices: [Device]
}
    
struct Device: Codable {
    let id: String
    let name: String
    let type: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case isActive = "is_active"
    }
}

struct SpotifySearchResponse: Codable {
    let tracks: SpotifyTracksResponse
    
    struct SpotifyTracksResponse: Codable {
        let items: [SpotifyTrackItem]
    }
    struct SpotifyTrackItem: Codable {
        let name: String
        let artists: [SpotifyArtist]
        let uri: String
    }
    struct SpotifyArtist: Codable {
        let name: String
    }
}
struct RecommendationResponse: Codable {
    let tracks: [Song]
}
struct Song: Codable {
    let title: String
    let artist: String
    let uri: String
    
    
    init(title: String, artist: String, uri: String) {
        self.title = title
        self.artist = artist
        self.uri = uri
    }
}

    
    
    struct TopArtistsResponse: Decodable {
        let items: [Artist]
    }
    
    struct Artist: Codable {
        let externalURLs: ExternalURLs
        let href: String
        let id: String
        let name: String
        let type: String
        let uri: String
        let popularity: Int?
        let genres: [String]?
        
        private enum CodingKeys: String, CodingKey {
            case externalURLs = "external_urls", href, id, name, type, uri,popularity, genres
        }
    }
    struct ExternalURLs: Codable {
        let spotify: String
    }
    
    struct AlbumImage: Codable {
        let url: String
        let height: Int
        let width: Int
    }
    
    struct Followers: Decodable {
        let total: Int
    }
    
    
    

struct SpotifyTrackResponse: Codable {
    let tracks: [TrackObject]
}

struct TrackObject: Codable {
    let album: Album?
    let id: String?
}

struct Album: Codable {
    let id: String
}

// Custom error types for SpotifyService
enum SpotifyServiceError: Error {
    case accessTokenUnavailable
    case urlConstructionError
    case noDataReceived
    case noResultsFound
    case unexpectedResponse
    case invalidURL
    case artistNotFound
}
enum SongFetchError: Error {
    case networkError(Error) // For general network request errors
    case dataSerializationError(Error) // For issues when decoding the response
    case responseError(String) // For errors returned by the Spotify API in the response body
    case tokenUnavailable // When the access token is not available or cannot be refreshed
    case invalidURL // When the URL for the Spotify API call cannot be constructed
    case noData // When the response from the Spotify API contains no data
    case invalidParameters // When the parameters for the Spotify API call are invalid or insufficient
    case llmResponseError
   
}

