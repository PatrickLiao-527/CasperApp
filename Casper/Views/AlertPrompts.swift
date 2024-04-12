//
//  AlertPrompts.swift
//  Casper
//
//  Created by Patrick Liao on 3/11/24.
//

import SwiftUI


struct AlertPrompt: View {
    @Binding var showSpotifyAlert: Bool
    @Binding var userInput: String
    @ObservedObject var appStateManager: AppStateManager
    @EnvironmentObject var spotifyService: SpotifyService

    // Additional state for handling the error message
    @State private var errorMessage: String?

    var body: some View {
        Button("Open Spotify") {
            spotifyService.playSong(userInput: userInput) { success, error in
                if success {
                    // Handle successful playback
                    self.showSpotifyAlert = false
                } else if let error = error, error == "Spotify is not opened" {
                    // This error message should match whatever message playSong would return in this scenario
                    self.errorMessage = error
                    self.showSpotifyAlert = true
                } else {
                    // Handle other errors
                    self.errorMessage = error ?? "An unknown error occurred."
                    self.showSpotifyAlert = true
                }
            }
        }
        .alert(isPresented: $showSpotifyAlert) {
            Alert(
                title: Text("Open Spotify"),
                message: Text(errorMessage ?? "Would you like to open Spotify now?"),
                primaryButton: .default(Text("Open Spotify")) {
                    if let spotifyUrl = URL(string: "spotify://") {
                        NSWorkspace.shared.open(spotifyUrl)
                    }
                },
                secondaryButton: .cancel {
                    self.errorMessage = nil // Clear the error message when dismissing the alert
                }
            )
        }
    }
}




