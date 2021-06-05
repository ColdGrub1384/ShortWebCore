//
//  AutomationRunnerDelegate.swift
//  ShortWeb
//
//  Created by Emma Labbé on 03-05-21.
//

import Foundation

/// Functions to get notified about the execution state of an `AutomationRunner` object.
public protocol AutomationRunnerDelegate {
    
    /// The given action will be executed.
    func automationRunner(_ automationRunner: AutomationRunner, willExecute action: Action, at index: Int)
    
    /// The given action produced the given output.
    func automationRunner(_ automationRunner: AutomationRunner, didGet result: Any, for action: Action, at index: Int)
    
    /// The automation finished running.
    func automationRunnerDidFinishRunning(_ automationRunner: AutomationRunner)
}
