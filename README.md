# ShortWebCore

This iOS library lets you run automations on Web Views.

## Example

(Optional) Declare class conforming to `AutomationRunnerDelegate`:

```swift

import ShortWebCore

class Delegate: AutomationRunnerDelegate {
    
    func automationRunner(_ automationRunner: AutomationRunner, didGet result: Any, for action: Action, at index: Int) {
        
        print("Action \(index) returned \(result)")
    }
    
    func automationRunnerDidFinishRunning(_ automationRunner: AutomationRunner) {
        print("Automation did finish running")
    }
    
    func automationRunner(_ automationRunner: AutomationRunner, willExecute action: Action, at index: Int) {
        
        print("Will run action at \(index)")
    }
}
```

Create an array of `Action`:

```swift

let actions = [
    Action(type: .openURL(URL(string: "https://www.google.com")!, false)),
    Action(type: .input("input[type=text]", "1 chf to clp")),
    Action(type: .click("input[type=submit][value='Google Search']")),
    Action(type: .urlChange),
    Action(type: .getResult("div[data-exchange-rate] > div:nth-of-type(2)"))
]
```

Actions take the path of an HTML element in the same format than `document.querySelector`. These are the type of actions:

```swift

/// The type of an `Action`.
public indirect enum ActionType : Codable {

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
}
```

Next, create a `WebView` object and an `AutomationRunner` to run the actions (must be done in the main thread):

```swift
let webView = ShortWebCore.WebView()

let runner = AutomationRunner(actions: actions, webView: webView)
let delegate = Delegate()
runner.delegate = delegate
runner.run { result in
    print(result)
}
```

The `result` parameter in the closure is an array of items returned by `.getResult(_:)` actions.

NOTE: The Web View should be in the view hierarchy to run correctly.

## Inspecting

`WebView` contains an `inspect(_:)` function that can be used to inspect the HTML elements in it. It takes a block with a `WebViewManager` parameter that runs in a background thread.

```swift

webView.inspect { manager in
    
}
```

`WebViewManager` has the following methods:

```swift

/// Checks if the HTML element at the given selector is a text box.
///
/// - Parameters:
///     - path: The selector of the element to check.
///     - iframePath: The HTML selector of an iframe if the element is located in there.
///
/// - Returns: `true` if the given element takes text input, if not, `false`.
public func isInput(_ path: String, onIframeAt iframePath: String? = nil) -> Bool

/// Checks if the HTML element at the given selector is an input for uploading a file.
///
/// - Parameters:
///     - path: The selector of the element to check.
///     - iframePath: The HTML selector of an iframe if the element is located in there.
///
/// - Returns: `true` if the given element takes a file as input, if not, `false`.
public func isFileInput(_ path: String, onIframeAt iframePath: String? = nil) -> Bool

/// Checks if the HTML element at the given selector is an iframe.
///
/// - Parameters:
///     - path: The selector of the element to check.
///
/// - Returns: `true` if the given element is an iframe.
public func isIframe(_ path: String) -> Bool

/// Returns the location of the element at the given path.
///
/// - Parameters:
///     - path: The selector of the element to check.
///
/// - Returns: The location of the element.
public func location(ofElementAt path: String) -> CGPoint

/// Get the HTML element at the given location in the given web view.
///
/// - Parameters:
///
///     - location: The location of the element.
///     - iframePath: The HTML selector of an iframe if the element is located in there.
///
/// - Returns: The selector of the element or an empty string if it does not exist.
public func element(at location: CGPoint, onIframeAt iframePath: String? = nil) -> String
```
