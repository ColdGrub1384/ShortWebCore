//
//  AutomationDocument.swift
//  ShortWeb
//
//  Created by Emma Labbé on 03-05-21.
//

import UIKit

/// A document contained a list of actions.
public class AutomationDocument: UIDocument, Identifiable {
    
    /// The actions contained in the document.
    public var actions = [Action]()
    
    public override func contents(forType typeName: String) throws -> Any {
        return try PropertyListEncoder().encode(actions)
    }
    
    public override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let data = contents as? Data {
            actions = try PropertyListDecoder().decode([Action].self, from: data)
        }
    }
}
