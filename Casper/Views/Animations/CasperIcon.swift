//
//  CasperIcon.swift
//  Casper
//
//  Created by Patrick Liao on 3/12/24.
//

import SwiftUI

struct CasperIcon: View{
    @Binding var appState: AppState
    var iconSize: CGFloat
    
    var body: some View{
        Image("CasperIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.default) {
                    if appState == .functionSelection{
                        appState = .idle
                    }else{
                        appState = .functionSelection
                    }
                }
            }
    }
}
