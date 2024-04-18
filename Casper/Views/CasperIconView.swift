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
        ZStack {
            casperIconAnimation
            additionalElements
        }
        .frame(width: maxFrameSize.width, height: maxFrameSize.height, alignment: .bottom)
        .border(Color.blue)
        .clipped() // Clip the frame to its bounds to prevent mouse events from being taken outside the visible area
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
            default:
                return AnyView(EmptyView())
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
    
    private var maxFrameSize: CGSize {
        let casperIconSize = casperIconSizeForState(appStateManager.appState)
        let additionalElementsSize = additionalElementsSizeForState(appStateManager.appState)
        
        let maxWidth = max(casperIconSize.width, additionalElementsSize.width)
        let totalHeight = casperIconSize.height + additionalElementsSize.height
        
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    private func casperIconSizeForState(_ state: AppState) -> CGSize {
        switch state {
        case .login, .idle, .functionSelection, .autoMonitoring, .hide, .calendarHelp:
            return CGSize(width: iconSize, height: iconSize)
        case .startNLInput, .userFinishedInput, .calendarReply, .systemReply:
            return CGSize(width: iconSize, height: iconSize)
        }
    }

    private func additionalElementsSizeForState(_ state: AppState) -> CGSize {
        switch state {
        case .functionSelection:
            return CGSize(width: iconSize + 10 , height: iconSize-10) // Adjust as needed
        case .startNLInput:
            return CGSize(width: iconSize * 2, height: iconSize) // Adjust as needed
        default:
            return CGSize(width: 0, height: 0) // No additional elements
        }
    }
}
