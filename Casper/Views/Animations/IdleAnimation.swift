//
//  IdleAnimation.swift
//  Casper
//
//  Created by Patrick Liao on 3/21/24.
//

import SwiftUI

struct IdleAnimation: View {
    let animationFrames = (1...13).map { "idle_frame\($0)" }
    @State private var currentFrameIndex = 0
    @State private var isPaused = false
    @EnvironmentObject var appStateManager: AppStateManager
    var iconSize: CGFloat
    let animationInterval = 1.0/24.0
    let pauseDuration = 3.0
    var body: some View {
        Image(animationFrames[currentFrameIndex])
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .onReceive(Timer.publish(every: isPaused ? pauseDuration : animationInterval, on: .main, in: .common).autoconnect()) { _ in
                if isPaused {
                    // End the pause
                    isPaused = false
                } else {
                    // Increment the frame index or pause after the last frame
                    if currentFrameIndex < animationFrames.count - 1 {
                        currentFrameIndex += 1
                    } else {
                        currentFrameIndex = 0
                        isPaused = true // Begin the pause
                    }
                }
            }
            .onTapGesture {
                // Toggle the appState when the animation is tapped
                if appStateManager.appState == .functionSelection {
                    appStateManager.appState = .idle
                } else {
                    appStateManager.appState = .functionSelection
                }
            }
    }
}
