import SwiftUI



struct CasperIconView: View {
    @State var showingPanel = false
    @EnvironmentObject var appStateManager: AppStateManager
    var window: NSWindow?
    @State private var showAlert = false
    @State private var showIcons = false
    @State private var alertMessage = ""
    //Spotify Services
    @State private var activeAppChecker = ActiveAppChecker()
    @State private var connected = false
    @EnvironmentObject var spotifyService: SpotifyService
    //Calendar Services
    var calendarService: CalendarService?
    //General
    let iconSize: CGFloat = 100
    var body: some View {
        VStack {
            if appStateManager.appState == .login{
                LoginAnimationView(iconSize: iconSize)
            }else if appStateManager.appState == .idle || appStateManager.appState == .functionSelection {
                VStack {
                    if appStateManager.appState == .functionSelection {
                        functionSelectionView
                    }
                    IdleAnimation(iconSize: iconSize)
                }
            }else if appStateManager.appState == .startNLInput{
                withAnimation{
                    VStack{
                        UserTextBox(apiToUse: "Spotify",
                                    iconSize: iconSize)
                        UserTypeRequestAnimation(iconSize: iconSize)
                    }
                }
            }else if appStateManager.appState == .userFinishedInput{
                ConfirmActionAnimation(iconSize: iconSize)
                
            }else if appStateManager.appState == .autoMonitoring{
                VStack {
                    if appStateManager.appState == .functionSelection {
                        functionSelectionView
                    }
                    IdleAnimation(iconSize: iconSize)
                }
            }else if appStateManager.appState == .hide{
                HideAnimationView(iconSize: iconSize)
            }else if appStateManager.appState == .calendarHelp{
                VStack{
                    UserTextBox(apiToUse: "Calendar",
                                iconSize: iconSize
                    )
                    IdleAnimation(iconSize: iconSize)
                }
            }else if appStateManager.appState == .calendarReply{
                VStack {
                    CasperTextBox(appStateManager: appStateManager, iconSize: iconSize)
                        .onAppear {
                            calendarService?.fetchTodaysEvents { success in
                                if success {
                                    calendarService?.scheduleEventMessages()
                                } else {
                                    calendarService?.systemMessage = "I couldn't access your calendar."
                                }
                            }
                        }
                        .onDisappear {
                            calendarService?.stopMessages()
                        }
                    IdleAnimation(iconSize: iconSize)
                }
            }else if appStateManager.appState == .systemReply{
                VStack{
                    CasperTextBox(appStateManager: appStateManager, iconSize: iconSize)
                    IdleAnimation(iconSize: iconSize)
                }
            }else{// some error happened?
                EmptyView()
            }
        }
        .frame(width: iconSize * 3, height: iconSize * 3, alignment: .center) // Adjust the frame as needed
    }
    private var functionSelectionView: some View {
        HStack(spacing: 20) {
            CustomInputIcon(connected: $connected,
                            spotifyService: _spotifyService,
                            iconSize: iconSize)
            
            AutoMonitoringIcon(activeAppChecker: $activeAppChecker,
                               iconSize: iconSize)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.8), value: appStateManager.appState)
    }
}



