import SwiftUI

struct CasperIconView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    var window: NSWindow?
    
    // Spotify Services
    @State private var activeAppChecker = ActiveAppChecker()
    @State private var connected = false
    @EnvironmentObject var spotifyService: SpotifyService
    
    // Calendar Services
    var calendarService: CalendarService?
    
    // General
    let iconSize: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                casperIconAnimation
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + iconSize/2)
                additionalElements
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + additionalElementsSizeForState(appStateManager.appState).height / 2)
            }
            //.border(Color.blue)
            .clipped()
        }
        

    }
    
    
    private var casperIconAnimation: some View {
        VStack {
            switch appStateManager.appState {
            case .login:
                return AnyView(LoginAnimationView(iconSize: iconSize))
            case .idle, .functionSelection, .autoMonitoring, .hide:
                return AnyView(IdleAnimation(iconSize: iconSize))
            case .startNLInput:
                return AnyView(UserTypeRequestAnimation(iconSize: iconSize))
            case .userFinishedInput:
                return AnyView(ConfirmActionAnimation(iconSize: iconSize))
            case .calendarHelp:
                return AnyView(UserTextBox(apiToUse: "Calendar", iconSize: iconSize))
            case .calendarReply, .systemReply:
                return AnyView(CasperTextBox(appStateManager: appStateManager, iconSize: iconSize))
//            default:
//                return AnyView(EmptyView())
            }
        }
    }
    private var additionalElements: some View {
        VStack {
            switch appStateManager.appState {
            case .functionSelection:
                return AnyView(functionSelectionView)
            case .startNLInput:
                return AnyView(UserTextBox(apiToUse: "Spotify", iconSize: iconSize))
            default:
                return AnyView(EmptyView())
            }
        }
        .offset(y: -iconSize) // Offset the additional elements above the CasperIconAnimation
    }
    private func additionalElementsOffset() -> CGFloat {
//        let additionalElementsSize = additionalElementsSizeForState(appStateManager.appState)
//        return (additionalElementsSize.height / 2) + 20 // Add some padding
        return 20
    }
    private func additionalElementsSizeForState(_ state: AppState) -> CGSize {
        switch state {
        case .functionSelection:
            return CGSize(width: iconSize + 20 , height: iconSize-10) // Adjust as needed
        case .startNLInput:
            return CGSize(width: iconSize * 2, height: iconSize) // Adjust as needed
        default:
            return CGSize(width: 0, height: 0) // No additional elements
        }
    }
    private var functionSelectionView: some View {
        HStack(spacing: 20) {
            CustomInputIcon(connected: $connected,
                            spotifyService: _spotifyService,
                            iconSize: iconSize)
            
            AutoMonitoringIcon(activeAppChecker: $activeAppChecker,
                               iconSize: iconSize)
        }
        .animation(.easeInOut(duration: 0.8), value: appStateManager.appState)
    }
}
