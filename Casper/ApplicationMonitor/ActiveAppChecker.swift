//
//  ActiveAppChecker.swift
//  Casper
//
//  Created by Patrick Liao on 3/11/24.
//

import Foundation
import AppKit
import Cocoa

class ActiveAppChecker{
    func printActiveApplications() {
        let apps = NSWorkspace.shared.runningApplications
        var activeApps = [String]()
        var inactiveApps = [String]()
        for app in apps where app.isActive {
            activeApps.append(app.localizedName ?? "Unknown app")
        }
        for app in apps where !app.isActive {
            inactiveApps.append(app.localizedName ?? "Unknown app")
        }
        print("Active apps running: \(activeApps)")
        print("Inactive apps running: \(inactiveApps)")
        
        // Check if Google Chrome is running and run the script accordingly
        if activeApps.contains("Google Chrome") || inactiveApps.contains("Google Chrome") {
            DispatchQueue.global(qos: .background).async {
                print ("Google Chrome is running")
                self.runChromeTabsScript()
                DispatchQueue.main.async {
                    // Update UI if necessary
                }
            }
        }
        
        // Check if Safari is running and run the script accordingly
        if activeApps.contains("Safari") || inactiveApps.contains("Safari") {
            DispatchQueue.global(qos: .background).async {
                self.runSafariTabsScript()
                DispatchQueue.main.async {
                    // Update UI if necessary
                }
            }
        }
    }
    func isApplicationRunning(appBundleIdentifier: String) -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: appBundleIdentifier)
        return !apps.isEmpty
    }
    func runChromeTabsScript() {
        let script = """
            set outputText to ""
            tell application "Google Chrome"
                repeat with w from 1 to count of windows
                    set theWindow to window w
                    repeat with t from 1 to count of tabs of theWindow
                        set theTab to tab t of theWindow
                        set outputText to outputText & "Title: " & title of theTab & ", URL: " & URL of theTab & "\\n"
                    end repeat
                end repeat
            end tell
            return outputText
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let outputEvent = appleScript.executeAndReturnError(&error)
            if let outputString = outputEvent.stringValue {
                print(outputString)
            } else if let error = error {
                print("Error: \(error)")
            }
        }
    }
    func runSafariTabsScript() {
        let script = """
            set outputText to ""
            tell application "Safari"
                repeat with w from 1 to count of windows
                    set theWindow to window w
                    repeat with t from 1 to count of tabs of theWindow
                        set theTab to tab t of theWindow
                        set outputText to outputText & "Title: " & title of theTab & ", URL: " & URL of theTab & "\\n"
                    end repeat
                end repeat
            end tell
            return outputText
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let outputEvent = appleScript.executeAndReturnError(&error)
            if let outputString = outputEvent.stringValue {
                print(outputString)
            } else if let error = error {
                print("Error: \(error)")
            }
        }
    }

}
