//
//  ConfirmActionAnimation.swift
//  Casper
//
//  Created by Patrick Liao on 3/12/24.
//

import SwiftUI

struct ConfirmActionAnimation: View {
    let images = ["Casper_confirm_action1_icon", "Casper_confirm_action2_icon", "Casper_confirm_action3_icon"] //TODO: Might change? 
    @State private var index = 0
    @EnvironmentObject var appStateManager: AppStateManager
    var iconSize: CGFloat
    
    var body: some View {
        Image(images[index])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
                    index = (index + 1) % images.count // Loop through the images
                    if index == images.count-1{
                        appStateManager.appState = .idle
                    }
                    
                }
            }
            
        
    }
}



