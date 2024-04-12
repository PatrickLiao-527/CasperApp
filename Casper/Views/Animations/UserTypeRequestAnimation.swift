import SwiftUI

struct UserTypeRequestAnimation: View {
    let animationFrames = (1...34).map { "Casper_type_request\($0)_icon" }
    @State private var currentFrameIndex = 0
    var iconSize: CGFloat
    @State private var timer: Timer? = nil
    @State private var pauseAtEnd = false

    var body: some View {
        Image(animationFrames[currentFrameIndex])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .onAppear {
                startAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
    }

    func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/24.0, repeats: true) { _ in
            if currentFrameIndex == 15 && !pauseAtEnd {
                // Pause at frame 15 for one second
                pauseAtEnd = true
                stopAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.currentFrameIndex += 1
                    self.startAnimation()
                }
            } else if currentFrameIndex < animationFrames.count - 1 {
                // Proceed with animation
                currentFrameIndex += 1
            } else {
                // End of loop, pause for a second
                stopAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    currentFrameIndex = 0
                    pauseAtEnd = false
                    self.startAnimation()
                }
            }
        }
    }

    func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}
