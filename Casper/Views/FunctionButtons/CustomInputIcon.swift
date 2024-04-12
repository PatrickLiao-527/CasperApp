//
//  CustomInputIcon.swift
//  Casper
//
//  Created by Patrick Liao on 3/12/24.
//

import SwiftUI

struct CustomInputIcon: View{
    @Binding var connected: Bool
    @EnvironmentObject var spotifyService: SpotifyService
    @EnvironmentObject var appStateManager: AppStateManager
    var iconSize: CGFloat
    var body: some View{
        Image("CustomInputIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize / 2, height: iconSize / 2)
            .onTapGesture {
                if !connected{
                    spotifyService.authenticateIfNeeded { success in
                        if success {
                            print ("connected to spotify")
                            connected = true
                            withAnimation {
                                DispatchQueue.main.async{
                                    appStateManager.appState = .startNLInput
                                }
                            }
                        } else {
                            print("Authentication failed.")
                        }
                    }
                }else{
                    withAnimation {
                        DispatchQueue.main.async{
                            appStateManager.appState = .startNLInput
                        }
                    }
                    
                }
            }

    }
}

