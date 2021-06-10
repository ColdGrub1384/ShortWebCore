//
//  WebViewManager.swift
//  ShortWeb
//
//  Created by Emma Labbé on 04-05-21.
//

import WebKit

/// A tuple containing values that can be passed to `WKWebView.evaluateJavaScript(_:in:in:)` to evaluate JS code in an iframe.
public typealias IFrame = (frameInfo: WKFrameInfo, contentWorld: WKContentWorld)

/// A class that contains methods to inspect the content of a Web View.
public class WebViewManager: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    
    weak internal var webView: WKWebView?
    
    internal override init() {
        super.init()
    }
    
    var frames = [String : IFrame]()
    
    var mainFrame = (frameInfo: WKFrameInfo(), contentWorld: WKContentWorld.defaultClient)
    
    func setData(_ value: Any, key: String) {
        let ud = UserDefaults.standard
        let archivedPool = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
        ud.set(archivedPool, forKey: key)
    }

    func getData<T>(key: String) -> T? {
        let ud = UserDefaults.standard
        if let val = ud.value(forKey: key) as? Data,
           let obj = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(val) {
            return obj as? T
        }
        
        return nil
    }
    
    // MARK: - Navigation delegate
    
    /*public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        frames = [:]
        decisionHandler(.allow)
    }*/
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        webView.reloadInputViews()
        
        guard let jsURL = Bundle.module.url(forResource: "index", withExtension: "js") else {
            return
        }
        
        guard let js = try? String(contentsOf: jsURL) else {
            return
        }
        
        webView.evaluateJavaScript(js, completionHandler: nil)
        
        (webView as? WebView)?.didFinishNavigation?(navigation)
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            self.setData(cookies, key: "cookies")
        }
    }
        
    // MARK: - Script message handler
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        (webView as? WebView)?.didReceiveMessage?(message)
        
        let frame = message.frameInfo
        if frame.isMainFrame {
            mainFrame = (frameInfo: frame, contentWorld: message.world)
        } else if (message.body as? String) == "frame", let url = frame.request.url?.absoluteString {
            
            frames[url] = (frameInfo: frame, contentWorld: message.world)
            
            guard let jsURL = Bundle.module.url(forResource: "index", withExtension: "js") else {
                return
            }
            
            guard let js = try? String(contentsOf: jsURL) else {
                return
            }
            
            webView?.evaluateJavaScript(js, in: frame, in: message.world, completionHandler: nil)
        }
    }
    
    // MARK: - JS
    
    /// Returns the web kit frame info object corresponding to the given iframe.
    ///
    /// - Parameters:
    ///     - iframePath: The HTML selector of an iframe.
    ///
    /// - Returns: The frame info and the content world which urls corresponds to the iframe. Returns the main frame if no frame info is found.
    public func frame(for iframePath: String) -> IFrame {
        
        if Thread.current.isMainThread {
            fatalError("Cannot be called on the main thread")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var result = mainFrame
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("document.querySelector('\(iframePath)').src", completionHandler: { res, _ in
                if let res = res as? String {
                    result = self.frames[res] ?? self.mainFrame
                }
                semaphore.signal()
            })
        }
        
        semaphore.wait()
        
        if result.frameInfo.isMainFrame {
            Thread.sleep(forTimeInterval: 0.2)
            return frame(for: iframePath)
        }
        
        return result
    }
    
    /// Checks if the HTML element at the given selector is a text box.
    ///
    /// - Parameters:
    ///     - path: The selector of the element to check.
    ///     - iframePath: The HTML selector of an iframe if the element is located in there.
    ///
    /// - Returns: `true` if the given element takes text input, if not, `false`.
    public func isInput(_ path: String, onIframeAt iframePath: String? = nil) -> Bool {
        
        if Thread.current.isMainThread {
            fatalError("Cannot be called on the main thread")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var result = false
        
        var frame = mainFrame
        if let path = iframePath {
            frame = self.frame(for: path)
        }
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("""
            isInput(document.querySelector('\(path)'));
            """, in: frame.frameInfo, in: frame.contentWorld) { res in
                
                switch res {
                case .success(let res):
                    result = ((res as? Bool) != nil && (res as! Bool))
                    semaphore.signal()
                default:
                    break
                }
            }
        }
        
        semaphore.wait()
        
        return result
    }

    /// Checks if the HTML element at the given selector is an input for uploading a file.
    ///
    /// - Parameters:
    ///     - path: The selector of the element to check.
    ///     - iframePath: The HTML selector of an iframe if the element is located in there.
    ///
    /// - Returns: `true` if the given element takes a file as input, if not, `false`.
    public func isFileInput(_ path: String, onIframeAt iframePath: String? = nil) -> Bool {
        
        if Thread.current.isMainThread {
            fatalError("Cannot be called on the main thread")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var result = false
        
        var frame = mainFrame
        if let path = iframePath {
            frame = self.frame(for: path)
        }
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("""
            isFileInput(document.querySelector('\(path)'));
            """, in: frame.frameInfo, in: frame.contentWorld) { res in
                
                switch res {
                case .success(let res):
                    result = ((res as? Bool) != nil && (res as! Bool))
                    semaphore.signal()
                default:
                    break
                }
            }
        }
        
        semaphore.wait()
        
        return result
    }

    /// Checks if the HTML element at the given selector is an iframe.
    ///
    /// - Parameters:
    ///     - path: The selector of the element to check.
    ///
    /// - Returns: `true` if the given element is an iframe.
    public func isIframe(_ path: String) -> Bool {
        
        if Thread.current.isMainThread {
            fatalError("Cannot be called on the main thread")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var result = false
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("""
            (document.querySelector('\(path)') instanceof HTMLIFrameElement);
            """) { res, _ in
                
                result = ((res as? Bool) != nil && (res as! Bool))
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        return result
    }

    /// Returns the location of the element at the given path.
    ///
    /// - Parameters:
    ///     - path: The selector of the element to check.
    ///
    /// - Returns: The location of the element.
    public func location(ofElementAt path: String) -> CGPoint {
        
        if Thread.current.isMainThread {
            fatalError("Cannot be called on the main thread")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var result = CGPoint.zero
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("""
            getOffsetAsArray(document.querySelector('\(path)'));
            """) { res, _ in
                
                guard let array = res as? [Double] else {
                    semaphore.signal()
                    return
                }
                
                guard let x = array.first, let y = array.last else {
                    semaphore.signal()
                    return
                }
                
                result = CGPoint(x: x, y: y)
                
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        return result
    }

    /// Get the HTML element at the given location in the given web view.
    ///
    /// - Parameters:
    ///
    ///     - location: The location of the element.
    ///     - iframePath: The HTML selector of an iframe if the element is located in there.
    ///
    /// - Returns: The selector of the element or an empty string if it does not exist.
    public func element(at location: CGPoint, onIframeAt iframePath: String? = nil) -> String {
        
        if Thread.current.isMainThread {
            fatalError("Cannot be called on the main thread")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var result = ""
        
        var frame = mainFrame
        if let path = iframePath {
            frame = self.frame(for: path)
        }
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("""
            getDomPath(document.elementFromPoint(\(location.x), \(location.y)));
            """, in: frame.frameInfo, in: frame.contentWorld) { res in
                
                switch res {
                case .success(let res):
                    result = res as? String ?? ""
                    semaphore.signal()
                default:
                    break
                }
            }
        }
        
        semaphore.wait()
        
        return result
    }

}
