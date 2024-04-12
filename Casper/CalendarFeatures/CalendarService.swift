//
//  CalendarService.swift
//  Casper
//
//  Created by Patrick Liao on 3/22/24.
//

import EventKit
import SwiftUI
import Combine
class CalendarService: ObservableObject{
    //Checks and asks for user's permission to read and write their calendars
    private let eventStore = EKEventStore()
    @Published var systemMessage = ""
    private var currentEventIndex = 0
    private var messageTimer: Timer?
    var appStateManager: AppStateManager
    init(appStateManager: AppStateManager) {
        self.appStateManager = appStateManager
    }
    
    // Function to request access to the Event Store
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        let authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        print ("Current authorization status: \(authorizationStatus.rawValue)")
        switch authorizationStatus {
            case .authorized, .notDetermined:
                // Only request access if the status is not determined.
                if authorizationStatus == .notDetermined {
                    eventStore.requestFullAccessToEvents { granted, error in
                        if let error = error {
                            print("Error requesting calendar access: \(error.localizedDescription)")
                        } else if granted {
                            print("Calendar access granted")
                        } else {
                            print("Calendar access denied")
                        }
                        completion(granted, error)
                    }
                } else {
                    // We have access already
                    print("Already have calendar access")
                    completion(true, nil)
                }
            
            case .restricted, .denied:
                // Access has been restricted or denied.
                print("Calendar access denied")
                completion(false, nil)
                
        case .fullAccess:
            // We have access already
            print("Already have calendar access")
            completion(true, nil)
        case .writeOnly: // we need full access
            eventStore.requestFullAccessToEvents { granted, error in
                if let error = error {
                    print("Error requesting calendar access: \(error.localizedDescription)")
                } else if granted {
                    print("Calendar access granted")
                } else {
                    print("Calendar access denied")
                }
                completion(granted, error)
            }
        @unknown default:
                // Handle any future cases.
                fatalError("Unknown EKAuthorizationStatus case.")
        }
    }



    // Function to get user permission
    func eventSearch(start: Date, end: Date, calendarNames: [String]? = nil, eventName: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
            case .fullAccess:
                performEventSearch(start: start, end: end, calendarNames: calendarNames, eventName: eventName)
                completion?(true)
            case .writeOnly:
                print("The app has write-only access to the calendar.")
                completion?(false)
            case .denied, .restricted:
                print("Access to the calendar is denied or restricted.")
                completion?(false)
            case .notDetermined:
                eventStore.requestFullAccessToEvents { granted, error in
                    if granted {
                        self.performEventSearch(start: start, end: end, calendarNames: calendarNames, eventName: eventName)
                        completion?(true)
                    } else {
                        print("Access to calendar was not granted.")
                        completion?(false)
                    }
                }
            @unknown default:
                fatalError("Unknown EKAuthorizationStatus case.")
        }
    }


    private func performEventSearch(start: Date, end: Date, calendarNames: [String]?, eventName: String?) {
        // Assuming authorization has been granted...
        let calendars = eventStore.calendars(for: .event).filter { calendar -> Bool in
            guard let calendarNames = calendarNames else { return true } // Return all if no filter is provided
            return calendarNames.contains(calendar.title)
        }
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars.isEmpty ? nil : calendars)
        let events = eventStore.events(matching: predicate).filter { event -> Bool in
            guard let eventName = eventName else { return true } // Return all if no name filter is provided
            return event.title.range(of: eventName, options: .caseInsensitive) != nil
        }
        
        for event in events {
            print("Event title: \(event.title ?? "No title")")
        }
        DispatchQueue.main.async { [self] in
            let simpleEvents = events.map { SimpleEvent(title: $0.title, startDate: $0.startDate, endDate: $0.endDate) }
            appStateManager.CalendarEvents = simpleEvents
        }
    }
    //Temporary function for testing purposes 
    func fetchTodaysEvents(completion: ((Bool) -> Void)? = nil) {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        eventSearch(start: start, end: end, completion: completion)
    }

    func scheduleEventMessages() {
        currentEventIndex = 0
        // Ensure the timer schedules messages on the main thread
        DispatchQueue.main.async {
            self.messageTimer?.invalidate() // Invalidate any existing timer
            self.messageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.currentEventIndex == 0{
                    self.systemMessage = "I just checked your calendar and here's what I found"
                    self.currentEventIndex += 1
                }else if self.currentEventIndex <= self.appStateManager.CalendarEvents.count {
                    let event = self.appStateManager.CalendarEvents[self.currentEventIndex-1]
                    self.systemMessage = "\(event.title) from \(self.formatDate(event.startDate)) to \(self.formatDate(event.endDate))"
                    self.currentEventIndex += 1
                } else {
                    self.messageTimer?.invalidate()
                    self.systemMessage = "That's all for today's events."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        // Optionally, clear the events if they should not be reused
                        self.appStateManager.CalendarEvents.removeAll()
                        self.appStateManager.appState = .calendarHelp
                        // Reset any other necessary state
                    }
                }
            }
        }
    }



    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Call this method when your ContentView disappears
    func stopMessages() {
        messageTimer?.invalidate()
        messageTimer = nil
    }
    

}
