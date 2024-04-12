//
//  ClickThroughWindow.swift
//  Casper
//
//  Created by Patrick Liao on 3/4/24.
//

import Cocoa
import SwiftUI

class ClickThroughWindow: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        // Only forward mouse events if they're on the content view.
        let location = contentView?.convert(event.locationInWindow, from: nil) ?? .zero
        if let hitView = contentView?.hitTest(location), hitView.isDescendant(of: contentView!) {
            super.mouseDown(with: event)
        } else {
            // Ignore the click
        }
    }
}
