//
//  ActionType.swift
//  ShortWebCore
//
//  Created by Emma Labbé on 05-05-21.
//

import Foundation

fileprivate struct CodableIframeAction: Codable {
    
    var path: String
    
    var action: ActionType
}

fileprivate struct OpenURL: Codable {
    
    var url: URL
    
    var mobile: Bool
}

/// The type of an `Action`.
public indirect enum ActionType: Codable {
    
    /// Click on the given HTML selector.
    case click(String)
    
    /// Input the given text on the given HTML selector. The first parameter is the HTML selector and the second parameter is the text to input.
    case input(String, String)
    
    /// Interact with an element in an iframe. The first parameter is the HTML selector of the iframe and the second one is the action to execute in the iframe.
    case iframe(String, ActionType)
    
    /// Get a string or an `UIImage` from the given HTML selector.
    case getResult(String)
    
    /// Wait until the web view finishes loading a new URL.
    case urlChange
    
    /// Upload a file with the given URL on the given input.
    case uploadFile(String, URL)
    
    /// Open the given URL. The second argument is `true` to open the URL in mobile mode.
    case openURL(URL, Bool)
    
    enum CodingKeys: CodingKey {
        case click
        case input
        case urlChange
        case openURL
        case getResult
        case iframe
        case uploadFile
    }
    
    enum DecodingError: Error {
        case invalidKey
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.urlChange) {
            self = .urlChange
        } else if let path = try? container.decode(String.self, forKey: .click) {
            self = .click(path)
        } else if let values = try? container.decode([String].self, forKey: .input) {
            self = .input(values[0], values[1])
        } else if let url = try? container.decode(URL.self, forKey: .openURL) {
            self = .openURL(url, false)
        } else if let url = try? container.decode(OpenURL.self, forKey: .openURL) {
            self = .openURL(url.url, url.mobile)
        } else if let path = try? container.decode(String.self, forKey: .getResult) {
            self = .getResult(path)
        } else if let iframe = try? container.decode(CodableIframeAction.self, forKey: .iframe) {
            self = .iframe(iframe.path, iframe.action)
        } else if let uploadFile = try? container.decode([String].self, forKey: .uploadFile) {
            
            let path = uploadFile[0]
            let data = Data(base64Encoded: uploadFile[1]) ?? Data()
            
            do {
                var isStale = false
                self = .uploadFile(path, try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale))
            } catch {
                print(error.localizedDescription)
                
                self = .uploadFile(path, URL(fileURLWithPath: "/file"))
            }
        } else {
            throw DecodingError.invalidKey
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .click(let path):
            try container.encode(path, forKey: .click)
        case .input(let path, let input):
            try container.encode([path, input], forKey: .input)
        case .urlChange:
            try container.encode(true, forKey: .urlChange)
        case .openURL(let url, let mobile):
            try container.encode(OpenURL(url: url, mobile: mobile), forKey: .openURL)
        case .getResult(let path):
            try container.encode(path, forKey: .getResult)
        case .iframe(let path, let type):
            try container.encode(CodableIframeAction(path: path, action: type), forKey: .iframe)
        case .uploadFile(let path, let url):
            guard let data = try? url.bookmarkData() else {
                try container.encode([path, Data().base64EncodedString()], forKey: .uploadFile)
                return
            }
            
            try container.encode([path, data.base64EncodedString()], forKey: .uploadFile)
        }
    }
}
