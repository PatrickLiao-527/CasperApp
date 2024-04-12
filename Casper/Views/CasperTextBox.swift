//
//  CasperTextBox.swift
//  Casper
//
//  Created by Patrick Liao on 3/22/24.
//

import SwiftUI

struct CasperTextBox: View {
    @ObservedObject var appStateManager: AppStateManager
    var iconSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green)
                .shadow(radius: 10)
            Text(appStateManager.systemMessage)
                .foregroundColor(.white)
        }
        .padding()
        .frame(width: iconSize*2, height: iconSize)
    }
}
