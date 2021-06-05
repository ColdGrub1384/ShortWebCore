//
//  WebView.swift
//  ShortWebCore
//
//  Created by Emma Labbé on 27-05-21.
//

import WebKit

/// A Web View that can perform automations.
public class WebView: WKWebView {
        
    private let manager = WebViewManager()
    
    internal var automationRunner: AutomationRunner?
    
    /// A closure called when the web view finishes the given navigation.
    public var didFinishNavigation: ((WKNavigation) -> Void)?
    
    internal var didReceiveMessage: ((WKScriptMessage) -> Void)?
    
    let group = DispatchGroup()
    
    // https://stackoverflow.com/a/52109021/7515957
    private func makeConfiguration() {
        
        //Need to reuse the same process pool to achieve cookie persistence
        let processPool: WKProcessPool

        if let pool: WKProcessPool = manager.getData(key: "pool")  {
            processPool = pool
        }
        else {
            processPool = WKProcessPool()
            manager.setData(processPool, key: "pool")
        }

        configuration.processPool = processPool
        
        if let cookies: [HTTPCookie] = manager.getData(key: "cookies") {
            
            for cookie in cookies {
                group.enter()
                configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                    print("Set cookie = \(cookie) with name = \(cookie.name)")
                    self.group.leave()
                }
            }
            
        }
    }
    
    /// Sets the web view content mode to mobile or desktop.
    ///
    /// - Parameters:
    ///     - mobile: `true` to display web pages in mobile mode.
    public func setContentMode(mobile: Bool) {
        if mobile {
            configuration.defaultWebpagePreferences.preferredContentMode = .mobile
            customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1 Mobile/15E148 Safari/604.1"
            frame.size = CGSize(width: 400, height: 1000)
        } else {
            configuration.defaultWebpagePreferences.preferredContentMode = .desktop
            customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.2 Safari/605.1.15"
            frame.size = CGSize(width: 1500, height: 1000)
        }
    }
    
    private func configure() {
        frame.size = CGSize(width: 1500, height: 1000)
        
        isUserInteractionEnabled = false
        navigationDelegate = manager
        configuration.userContentController.add(manager, name: "ShortWeb")
        
        manager.webView = self
                
        configuration.userContentController.addUserScript(WKUserScript(source: """
            window.webkit.messageHandlers.ShortWeb.postMessage("frame");
            """, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        
        allowDisplayingKeyboardWithoutUserAction()
        
        makeConfiguration()
    }
    
    init() {
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        
        configure()
    }
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Calls the given block with a `WebViewManager` obejct asynchronously in a background thread to inspect the Web View.
    ///
    /// - Parameters:
    ///     - block: A closure that takes a `WebViewManager` object. Use it to inspect the content of the web view.
    public func inspect(_ block: @escaping ((WebViewManager) -> Void)) {
        DispatchQueue.global().async {
            block(self.manager)
        }
    }
    
    // MARK: - Keyboard
    
    typealias OldClosureType =  @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Any?) -> Void
    typealias NewClosureType =  @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void
    
    func allowDisplayingKeyboardWithoutUserAction() {
            guard let WKContentView: AnyClass = NSClassFromString("WKContentView") else {
                print("allowDisplayingKeyboardWithoutUserAction extension: Cannot find the WKContentView class")
                return
            }
            var selector: Selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:")
            if let method = class_getInstanceMethod(WKContentView, selector) {
                let originalImp: IMP = method_getImplementation(method)
                let original: NewClosureType = unsafeBitCast(originalImp, to: NewClosureType.self)
                let block : @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void = { (me, arg0, arg1, arg2, arg3, arg4) in
                    original(me, selector, arg0, true, arg2, arg3, arg4)
                }
                let override: IMP = imp_implementationWithBlock(block)

                method_setImplementation(method, override);
            }
            guard let WKContentViewAgain: AnyClass = NSClassFromString("WKApplicationStateTrackingView_CustomInputAccessoryView") else {
                print("allowDisplayingKeyboardWithoutUserAction extension: Cannot find the WKApplicationStateTrackingView_CustomInputAccessoryView class")
                return
            }
            selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:")
            if let method = class_getInstanceMethod(WKContentViewAgain, selector) {
                let originalImp: IMP = method_getImplementation(method)
                let original: NewClosureType = unsafeBitCast(originalImp, to: NewClosureType.self)
                let block : @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void = { (me, arg0, arg1, arg2, arg3, arg4) in
                    original(me, selector, arg0, true, arg2, arg3, arg4)
                }
                let override: IMP = imp_implementationWithBlock(block)
                
                method_setImplementation(method, override);
            }
        }
}
