//
//  Action.swift
//  ShortWeb
//
//  Created by Emma Labbé on 02-05-21.
//

import SwiftUI

/// An automatic action to be executed on a web view.
public struct Action: Hashable, Codable {
    
    public var id = UUID()
        
    /// The type of the action.
    public var type: ActionType
    
    /// A timeout if the element does not exist.
    public var timeout: TimeInterval
    
    /// Initialize an action with the given type.
    ///
    /// - Parameters:
    ///     - type: The type of the action.
    ///     - timeout: A timeout if the element does not exist.
    public init(type: ActionType, timeout: TimeInterval = 0) {
        self.type = type
        self.timeout = timeout
    }
    
    /// The JavaScript code to be executed.
    public var code: String {
        switch type {
        case .click(let path):
            return "click(document.querySelector('\(path)'))"
        case .input(let path, _):
            return "document.querySelector('\(path)').focus()"
        case .getResult(let path):
            return "getData(document.querySelector('\(path)'));"
        case .iframe(_, let actionType):
            switch actionType {
            case .input(let path, let input):
                return "input(document.querySelector('\(path)'), '\(input.data(using: .utf8)?.base64EncodedString() ?? "")')"
            default:
                return Action(type: actionType).code
            }
        case .uploadFile(let path, _):
            return Action(type: .click(path)).code
        default:
            return ""
        }
    }
    
    public var accessibilityLabel: Text {
        switch type {
        case .click(_):
            return Text("Click element")
        case .input(_, let input):
            return Text("Input '\(input)'")
        case .urlChange:
            return Text("URL Change")
        case .openURL(let url, _):
            return Text("Open \(url.absoluteString)")
        case .uploadFile(_, let url):
            return Text("Upload \(url.lastPathComponent)")
        case .iframe(_, let actionType):
            return Action(type: actionType).accessibilityLabel
        case .getResult(_):
            return Text("Get content")
        }
    }
    
    /// The description of the action as a SwiftUI text.
    public var description: Text {
        switch type {
        case .click(let path):
            return (Text("Click element at ") + Text(path).font(.footnote).fontWeight(.thin))
        case .input(let path, let input):
            return Text("Type ") + Text(input).font(.footnote).fontWeight(.thin) + Text(" at ") + Text(path).font(.footnote).fontWeight(.thin)
        case .urlChange:
            return Text("URL change")
        case .openURL(let url, let mobile):
            return Text("Open ") + Text(url.absoluteString).font(.footnote).fontWeight(.thin) + Text(" (\(mobile ? "Mobile" : "Desktop"))")
        case .getResult(let path):
            return Text("Get content at ") + Text(path).font(.footnote).fontWeight(.thin)
        case .iframe(let path, let action):
            return Text("In iframe at ") + Text(path).font(.footnote).fontWeight(.thin) + Text(" ") + Action(type: action).description
        case .uploadFile(let path, let url):
            return Text("Upload ") + Text(url.lastPathComponent).font(.footnote).fontWeight(.thin) + Text(" at ") + Text(path).font(.footnote).fontWeight(.thin)
        }
    }
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case type
        case timeout
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timeout, forKey: .timeout)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(ActionType.self, forKey: .type)
        timeout = (try? container.decode(TimeInterval.self, forKey: .timeout)) ?? 0
    }
    
    // MARK: - Hashable
    
    public static func == (lhs: Action, rhs: Action) -> Bool {
        return lhs.description == rhs.description && lhs.timeout == rhs.timeout
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine("\(description)")
    }
}
