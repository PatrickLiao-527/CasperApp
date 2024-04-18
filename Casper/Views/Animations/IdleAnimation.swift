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
    let animationInterval = 1.0 / 24.0
    let pauseDuration = 3.0

    // Add gesture state to track drag
    @GestureState private var isDragging = false
    @State private var dragDetected = false

    var body: some View {
        Image(animationFrames[currentFrameIndex])
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .contentShape(Rectangle())
            .onReceive(Timer.publish(every: isPaused ? pauseDuration : animationInterval, on: .main, in: .common).autoconnect()) { _ in
                if isPaused {
                    isPaused = false
                } else {
                    if currentFrameIndex < animationFrames.count - 1 {
                        currentFrameIndex += 1
                    } else {
                        currentFrameIndex = 0
                        isPaused = true
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($isDragging) { value, state, _ in
                        state = true
                    }
                    .onChanged { _ in
                        self.dragDetected = true
                    }
                    .onEnded { _ in
                        // Delay the reset of dragDetected to ensure it's not a long press
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            self.dragDetected = false
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        // Only toggle the app state if no drag has been detected
                        if !self.dragDetected {
                            self.toggleAppState()
                        }
                    }
            )
    }

    private func toggleAppState() {
        // Toggle the appState when the animation is tapped
        if appStateManager.appState == .functionSelection {
            appStateManager.appState = .idle
        } else {
            appStateManager.appState = .functionSelection
        }
    }

    enum DragState {
        case inactive
        case dragging

        var isInactive: Bool {
            self == .inactive
        }
    }
}
