//
//  UserTextBox.swift
//  Casper
//
//  Created by Patrick Liao on 3/5/24.
//

import SwiftUI
 
struct UserTextBox: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @State private var userInput = ""
    @State private var showSpotifyAlert = false
    var apiToUse: String
    var iconSize: CGFloat
    
    var body: some View {
        if apiToUse == "Spotify"{
            SpotifyUserTextBox(appStateManager: _appStateManager, iconSize: iconSize )
        }else if apiToUse == "Calendar"{
            CalendarUserTextBox(iconSize: iconSize)
        }
    }
}
struct CalendarUserTextBox: View{
    @State var userInput = ""
    @EnvironmentObject var appStateManager: AppStateManager
    let calendarService = CalendarService(appStateManager: AppStateManager.shared)
    var iconSize: CGFloat
    var body: some View{
        VStack{
            TextField("What would you like me to do with your calendar?", text: $userInput)
                .foregroundStyle(.black)
                .onSubmit {
                    calendarService.requestAccess { granted, error in
                        if granted {
                            
                            DispatchQueue.main.async{
                                appStateManager.appState = .calendarReply
                                calendarService.fetchTodaysEvents()  
                                print ("trying to reply with calendar info")
                            }
                            
                        } else {
                            print("Access to calendar was denied or there was an error.")
                        }
                    }
                }

            }
        .foregroundColor(.black)
        .padding()
        .frame(width: iconSize*2, height: iconSize)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
        }
        
    
}
struct SpotifyUserTextBox: View {
    @State private var userInput = ""
    @State private var showSpotifyAlert = false
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var spotifyService: SpotifyService
    var iconSize: CGFloat

    var body: some View {
        VStack {
            TextField("Type a song name...", text: $userInput)
                .foregroundColor(.black)
                .padding()
                .onSubmit {
                    guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        print("User input is empty.")
                        return
                    }
                    spotifyService.playSong(userInput: userInput) { success, errorMessage in
                        DispatchQueue.main.async {
                            if success {
                                // If the song plays successfully, change the state to indicate user has finished input
                                self.appStateManager.appState = .userFinishedInput
                            } else {
                                // Check the specific error message indicating no devices found or failed to fetch devices
                                if let errorMessage = errorMessage, errorMessage == "No available devices found or failed to fetch devices." {
                                    // This error message matches the scenario where no devices were found or there was a failure fetching devices
                                    self.showSpotifyAlert = true
                                } else {
                                    // For any other errors, transition to systemReply view to handle it accordingly
                                    self.appStateManager.appState = .systemReply
                                }
                            }
                            if !showSpotifyAlert {
                                // If not showing the alert, clear the user input and update the state to reflect the change (functionSelection or other)
                                userInput = ""
                                self.appStateManager.appState = .functionSelection
                            }
                        }
                    }
                }
            // Assuming AlertPrompt is properly set up to handle the displaying of alerts,
            // This conditional presentation of AlertPrompt is removed because it's not how SwiftUI handles alerts.
            // Alerts should be attached to views using the .alert modifier.
        }
        .frame(width: iconSize * 2, height: iconSize) // Set the frame size of the VStack
        .background(Color.white) // Set the background color
        .cornerRadius(10) // Round the corners
        .shadow(radius: 10) // Apply shadow for better visibility
        // Attach the alert directly to this VStack using the .alert modifier.
        if showSpotifyAlert{
            AlertPrompt(showSpotifyAlert: $showSpotifyAlert, userInput: $userInput, appStateManager: appStateManager, spotifyService: _spotifyService)
        }
    }
}
