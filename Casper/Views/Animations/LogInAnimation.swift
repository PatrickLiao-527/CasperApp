//
//  LogInAnimation.swift
//  Casper
//
//  Created by Patrick Liao on 3/21/24.
//

import SwiftUI

struct LoginAnimationView: View {
    let animationFrames = (1...19).map { "Login_frame\($0)" }
    @State private var currentFrameIndex = 0
    @EnvironmentObject var appStateManager: AppStateManager
    var iconSize: CGFloat
    let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect() // Adjust the time interval as needed

    var body: some View {
        Image(animationFrames[currentFrameIndex])
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .onReceive(timer) { _ in
                // Increment the frame index, and check if we've reached the end.
                if currentFrameIndex < animationFrames.count - 1 {
                    currentFrameIndex += 1
                } else {
                    appStateManager.appState = .idle
                    timer.upstream.connect().cancel()
                }
            }
    }
}

