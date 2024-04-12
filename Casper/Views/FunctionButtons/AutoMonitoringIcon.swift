//
//  AutoMonitoringIcon.swift
//  Casper
//
//  Created by Patrick Liao on 3/12/24.
//

import SwiftUI
struct AutoMonitoringIcon: View{
    @Binding var activeAppChecker: ActiveAppChecker
    @EnvironmentObject var appStateManager: AppStateManager
    var iconSize: CGFloat
    var body: some View{
        Image("AutoMonitoringIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize / 2, height: iconSize / 2)
            .onTapGesture{
                activeAppChecker.printActiveApplications()
                appStateManager.appState = .autoMonitoring
            }
    }
}
