//
//  HideAnimation.swift
//  Casper
//
//  Created by Patrick Liao on 3/21/24.
//

import SwiftUI

struct HideAnimationView: View {
    let animationFrames = (1...13).map { "hide_frame\($0)" }
    @State private var currentFrameIndex = 0
    @State private var animationCompleted = false // New state to track completion
    @EnvironmentObject var appStateManager: AppStateManager
    var iconSize: CGFloat
    let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if animationCompleted {
                EmptyView()
            } else {
                Image(animationFrames[currentFrameIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .onReceive(timer) { _ in
                        // Increment the frame index, and check if we've reached the end.
                        if currentFrameIndex < animationFrames.count - 1 {
                            currentFrameIndex += 1
                        } else {
                            withAnimation {
                                animationCompleted = true
                            }
                            timer.upstream.connect().cancel()
                        }
                    }
            }
        }
    }
}
