//
//  AutomationRunner.swift
//  ShortWeb
//
//  Created by Emma Labbé on 03-05-21.
//

import WebKit
import UserNotifications
import UniformTypeIdentifiers

/// An `AutomationRunner` manages the execution of its assigned actions in a web view.
public class AutomationRunner: NSObject {
    
    /// The actions to execute.
    public var actions: [Action]
    
    /// The web view in which the actions will be executed.
    public var webView: WKWebView
    
    /// The object that will get notified on the state of the executed.
    public var delegate: AutomationRunnerDelegate?
    
    /// The results from the `ActionType.getResult(_)` actions.
    public var results = [Any]()
    
    internal var semaphore: DispatchSemaphore?
    
    internal var iframeSemaphore: DispatchSemaphore?
    
    private var searchingForPath: String?
    
    private var previousDelegate: WKNavigationDelegate?
    
    private var completion: (([Any]) -> Void)?
    
    private var _stop = false
    
    private var webViewWasVisible = true
    
    private var backgroundTask: UIBackgroundTaskIdentifier?
    
    /// Initializes the automation runner with the given actions and web view.
    ///
    /// - Parameters:
    ///     - actions: The actions to be executed.
    ///     - webView: The web view in which the actions will be executed.
    public init(actions: [Action], webView: WebView) {
        self.actions = actions
        self.webView = webView
        super.init()
        webView.didFinishNavigation = { _ in
            self.semaphore?.signal()
        }
    }
    
    private func evaluateSynchronously(_ script: String, iframe: IFrame? = nil) -> Any? {
        let semaphore = DispatchSemaphore(value: 0)
        
        var result: Any?
        
        DispatchQueue.main.async {
            if let iframe = iframe {
                self.webView.evaluateJavaScript(script, in: iframe.frameInfo, in: iframe.contentWorld) { res in
                    switch res {
                    case .success(let res):
                        result = res
                    default:
                        break
                    }
                    
                    semaphore.signal()
                }
            } else {
                self.webView.evaluateJavaScript(script) { res, _ in
                    result = res
                    semaphore.signal()
                }
            }
        }
        
        semaphore.wait()
        
        return result
    }
    
    /// Stops the execution of the actions.
    public func stop() {
        _stop = true
        DispatchQueue.main.async {
            if self.webView.isLoading {
                self.webView.stopLoading()
            }
            
            self.webView.load(URLRequest(url: URL(string: "about:blank")!))
            
            self.semaphore?.signal()
        }
    }
    
    private var waitingAction: Action?
    
    private var waitingFrame: IFrame?
    
    private func executeAction(at index: Int, frame: IFrame? = nil, customAction: Action? = nil) {
        guard actions.indices.contains(index) && !_stop else {
            
            print("Ended with results: \(results)")
            
            self.completion?(self.results)
            DispatchQueue.main.async {
                self.completion = nil
                self._stop = false
                
                if !self.webViewWasVisible {
                    self.webView.removeFromSuperview()
                }
                
                self.webViewWasVisible = true
                
                if let task = self.backgroundTask {
                    (UIApplication.perform(NSSelectorFromString("sharedApplication")).takeUnretainedValue() as? UIApplication)?.endBackgroundTask(task)
                }
                
                self.delegate?.automationRunnerDidFinishRunning(self)
            }
            return
        }
        
        let action = customAction ?? actions[index]
        
        switch action.type {
        case .iframe(_, _):
            break
        default:
            DispatchQueue.main.async {
                self.delegate?.automationRunner(self, willExecute: action, at: index)
            }
        }
        
        switch action.type {
        case .openURL(let url, let mobile): // Open the URL and wait
            semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.main.async {
                (self.webView as? WebView)?.setContentMode(mobile: mobile)
                self.webView.load(URLRequest(url: url))
            }
            semaphore?.wait()
            executeAction(at: index+1)
        case .urlChange: // Just wait till a new URL is loaded
            semaphore = DispatchSemaphore(value: 0)
            semaphore?.wait()
            executeAction(at: index+1)
        case .click(let path), .input(let path, _), .getResult(let path), .uploadFile(let path, _), .iframe(let path, _):
            
            if evaluateSynchronously("document.querySelector('\(path)') == null", iframe: frame) as? Bool == true { // Doesn't exist, wait
                
                waitingAction = action
                waitingFrame = frame
                
                var finishedBecauseOfTheTimeout = false
                
                if action.timeout > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now()+action.timeout) {
                        
                        guard self.waitingAction == action else {
                            return
                        }
                        
                        finishedBecauseOfTheTimeout = true
                        self.semaphore?.signal()
                    }
                }
                
                semaphore = DispatchSemaphore(value: 0)
                semaphore?.wait()
                
                waitingAction = nil
                
                if finishedBecauseOfTheTimeout {
                    return self.executeAction(at: index+1)
                }
                
                self.executeAction(at: index)
                
                waitingFrame = nil
                
            } else { // Exists
                                
                switch action.type {
                case .iframe(let iframePath, let actionType):
                    (webView as? WebView)?.inspect({ manager in
                        return self.executeAction(at: index, frame: manager.frame(for: iframePath), customAction: Action(type: actionType))
                    })
                    return
                case .input(let path, _):
                    if action.askForValueEachTime {
                        func didProvideInput(_ input: String) {
                            self.executeAction(at: index, frame: frame, customAction: Action(type: .input(path, input), timeout: action.timeout))
                        }
                        
                        self.delegate?.automationRunner(self, shouldProvideInput: didProvideInput, for: action, at: index)
                        return
                    }
                default:
                    break
                }
                
                if index > 0 {
                    Thread.sleep(forTimeInterval: 1)
                }
                
                switch actions[index].type {
                case .getResult(_): // Wait till src != undefined
                    if path.hasSuffix("> img") && evaluateSynchronously("isSrcUndefined(document.querySelector('\(path)'))", iframe: frame) as? Bool == true {
                        return queue.asyncAfter(deadline: .now()+0.5, execute: {
                            self.executeAction(at: index)
                        })
                    }
                default:
                    break
                }
                
                (self.webView as? WebView)?.inspect({ manager in
                    let frame = frame ?? manager.mainFrame
                    DispatchQueue.main.async {
                        var code = action.code
                        if !frame.frameInfo.isMainFrame {
                            switch action.type {
                            case .input(_, _):
                                code = Action(type: .iframe("", action.type)).code
                            default:
                                break
                            }
                        }
                        self.webView.evaluateJavaScript(code, in: frame.frameInfo, in: frame.contentWorld) { result in
                            
                            switch result {
                            case .success(let result):
                                switch action.type {
                                case .input(_, let input):
                                    if frame.frameInfo.isMainFrame {
                                        DispatchQueue.main.async {
                                            ((self.webView.value(forKey: "_contentView") as? NSValue)?.nonretainedObjectValue as? UITextInput)?.insertText(input)
                                        }
                                    }
                                case .uploadFile(_, let url):
                                    if self.webView.window == nil {
                                        NSLog("The web view currently running an automation is not in the view hierarchy and a file upload dialog was presented. The file upload could not be automatized.")
                                    } else if !action.askForValueEachTime {
                                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                                            
                                            var presented = self.webView.window?.rootViewController
                                            
                                            while true {
                                                
                                                presented = presented?.presentedViewController
                                                
                                                // _UIContextMenuActionsOnlyViewController
                                                if presented != nil, type(of: presented!) == NSClassFromString(String(data: Data(base64Encoded: "X1VJQ29udGV4dE1lbnVBY3Rpb25zT25seVZpZXdDb250cm9sbGVy")!, encoding: .utf8)!) {
                                                    break
                                                }
                                                
                                                if presented == nil {
                                                    break
                                                }
                                            }
                                            
                                            // _contentView,_fileUploadPanel
                                            guard let panel = (((self.webView.value(forKey: String(data: Data(base64Encoded: "X2NvbnRlbnRWaWV3")!, encoding: .utf8)!) as? NSValue)?.nonretainedObjectValue as? NSObject)?.value(forKey: String(data: Data(base64Encoded: "X2ZpbGVVcGxvYWRQYW5lbA==")!, encoding: .utf8)!) as? NSValue)?.nonretainedObjectValue as? UIDocumentPickerDelegate else {
                                                return
                                            }
                                                    
                                            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType("public.item")!])
                                            panel.documentPicker?(picker, didPickDocumentsAt: [url])
                                            
                                            presented?.dismiss(animated: true, completion: nil)
                                        }
                                    }
                                case .getResult(_): // Append the result
                                    
                                    if let result = result as? String, result.hasPrefix("data:image/") || result.hasPrefix("http:") || result.hasPrefix("https:"), let url = URL(string: result), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                                        
                                        self.results.append(image)
                                        self.delegate?.automationRunner(self, didGet: image, for: action, at: index)
                                    } else {
                                        self.results.append(result)
                                        self.delegate?.automationRunner(self, didGet: result, for: self.actions[index], at: index)
                                    }
                                default:
                                    break
                                }
                            case .failure(let error):
                                print(error.localizedDescription)
                            }
                            
                            DispatchQueue.global().async {
                                self.executeAction(at: index+1)
                            }
                        }
                    }
                })
            }
        }
    }
    
    let queue = DispatchQueue.global()
    
    /// Runs the receiver's actions. Will throw an error if not called from the main thread.
    ///
    /// - Parameters:
    ///     - completion: A block called when the execution is finished. Takes the results from `ActionType.getResult(_)` actions as parameter.
    public func run(completion: @escaping (([Any]) -> Void)) {
        guard Thread.current.isMainThread else {
            fatalError("`AutomationRunner.run` must be called from the main thread")
        }
        
        guard actions.count > 0 else {
            return
        }
        
        let app = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication
        
        if webView.superview == nil && webView.window == nil {
            webViewWasVisible = false
            webView.isHidden = true
            app?.windows.first?.addSubview(webView)
        }
        
        self.completion = completion
                
        (webView as? WebView)?.didReceiveMessage = { msg in
            self.didReceive(message: msg)
        }
        
        backgroundTask = app?.beginBackgroundTask(expirationHandler: nil)
        
        queue.async {
            self.executeAction(at: 0)
        }
    }
    
    func didReceive(message: WKScriptMessage) {
        
        if let str = message.body as? String, str == "DOM Change" {
            DispatchQueue.global().async {
                if let action = self.waitingAction {
                    switch action.type {
                    case .click(let path), .input(let path, _), .getResult(let path), .iframe(let path, _):
                        if self.evaluateSynchronously("document.querySelector('\(path)') != null", iframe: self.waitingFrame) as? Bool == true {
                            Thread.sleep(forTimeInterval: 0.5)
                            self.semaphore?.signal()
                        }
                    default:
                        self.semaphore?.signal()
                    }
                } else {
                    self.semaphore?.signal()
                }
            }
        }
    }
}
