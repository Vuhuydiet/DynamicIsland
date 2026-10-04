import SwiftUI
import AppKit
import WebKit

// MARK: - Web Plugin Configuration

public struct IslandWebConfiguration {
    public var initialURL: URL
    public var customUserAgent: String
    public var zoomFactor: Double
    public var customCSS: String?
    public var customJS: String?
    public var allowsBackForwardNavigationGestures: Bool
    
    public init(
        initialURL: URL,
        customUserAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
        zoomFactor: Double = 0.88,
        customCSS: String? = nil,
        customJS: String? = nil,
        allowsBackForwardNavigationGestures: Bool = true
    ) {
        self.initialURL = initialURL
        self.customUserAgent = customUserAgent
        self.zoomFactor = zoomFactor
        self.customCSS = customCSS
        self.customJS = customJS
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
    }
}

// MARK: - Web Plugin Controller

public class IslandWebController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    @Published public var title: String = ""
    @Published public var isLoading: Bool = false
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false
    @Published public var estimatedProgress: Double = 0.0
    @Published public var currentURL: URL?
    @Published public var pageTitleUnreadCount: Int = 0
    
    /// Callback when the web page issues an HTML5 Web Notification via window.Notification
    public var onNotificationReceived: ((_ title: String, _ body: String, _ icon: String?) -> Void)?
    /// Callback when the page title changes indicating new incoming messages (e.g. (1) Alice: Hello)
    public var onTitleNotificationTriggered: ((_ count: Int, _ rawTitle: String) -> Void)?
    
    public let configuration: IslandWebConfiguration
    public private(set) var webView: WKWebView!
    
    private var titleObservation: NSKeyValueObservation?
    private var loadingObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private var canGoBackObservation: NSKeyValueObservation?
    private var canGoForwardObservation: NSKeyValueObservation?
    
    public init(configuration: IslandWebConfiguration) {
        self.configuration = configuration
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        
        // Persistent cookies, localStorage, session across island invocations
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        // Inject custom CSS & JS if provided
        let userContentController = WKUserContentController()
        
        if let css = configuration.customCSS {
            let cssSource = """
            var style = document.createElement('style');
            style.innerHTML = `\(css)`;
            document.head.appendChild(style);
            """
            let userScript = WKUserScript(source: cssSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }
        
        if let js = configuration.customJS {
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }
        
        // Inject Web Notifications API polyfill bridge
        let notificationBridgeJS = """
        (function() {
            if (window._islandNotificationBridgeInstalled) return;
            window._islandNotificationBridgeInstalled = true;
            
            function IslandWebNotification(title, options) {
                options = options || {};
                this.title = title || "";
                this.body = options.body || "";
                this.icon = options.icon || "";
                this.tag = options.tag || "";
                
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.islandNotification) {
                        window.webkit.messageHandlers.islandNotification.postMessage({
                            title: String(this.title),
                            body: String(this.body),
                            icon: String(this.icon),
                            tag: String(this.tag)
                        });
                    }
                } catch(e) {
                    console.error("[IslandWebNotification] Error posting message:", e);
                }
            }
            
            IslandWebNotification.permission = "granted";
            IslandWebNotification.requestPermission = function(callback) {
                if (typeof callback === "function") {
                    try { callback("granted"); } catch(e) {}
                }
                return Promise.resolve("granted");
            };
            
            IslandWebNotification.prototype.close = function() {};
            IslandWebNotification.prototype.addEventListener = function() {};
            IslandWebNotification.prototype.removeEventListener = function() {};
            IslandWebNotification.prototype.dispatchEvent = function() { return true; };
            
            window.Notification = IslandWebNotification;
            
            if (typeof navigator !== "undefined" && navigator.permissions && navigator.permissions.query) {
                var origQuery = navigator.permissions.query.bind(navigator.permissions);
                navigator.permissions.query = function(param) {
                    if (param && param.name === "notifications") {
                        return Promise.resolve({ state: "granted", onchange: null });
                    }
                    return origQuery(param);
                };
            }
        })();
        """
        let bridgeScript = WKUserScript(source: notificationBridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(bridgeScript)
        userContentController.add(self, name: "islandNotification")
        
        config.userContentController = userContentController
        
        // Optimize process configuration
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.customUserAgent = configuration.customUserAgent
        web.allowsBackForwardNavigationGestures = configuration.allowsBackForwardNavigationGestures
        web.pageZoom = CGFloat(configuration.zoomFactor)
        
        // Set transparent background to blend into Island glass
        web.setValue(false, forKey: "drawsBackground")
        
        self.webView = web
        
        setupObservers()
        loadInitialURL()
    }
    
    public func loadInitialURL() {
        let request = URLRequest(
            url: configuration.initialURL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 30.0
        )
        webView.load(request)
    }
    
    public func reload() {
        webView.reload()
    }
    
    public func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    public func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    @Published public var currentZoom: Double = 0.88
    
    public func openInExternalBrowser() {
        let target = webView.url ?? configuration.initialURL
        NSWorkspace.shared.open(target)
    }
    
    public func setZoom(_ zoom: Double) {
        currentZoom = max(0.50, min(1.50, zoom))
        webView.pageZoom = CGFloat(currentZoom)
    }
    
    public func zoomIn() {
        setZoom(currentZoom + 0.08)
    }
    
    public func zoomOut() {
        setZoom(currentZoom - 0.08)
    }
    
    public func resetZoom() {
        setZoom(configuration.zoomFactor)
    }
    
    public func clearCache(completion: (() -> Void)? = nil) {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: dateFrom) { [weak self] in
            DispatchQueue.main.async {
                self?.loadInitialURL()
                completion?()
            }
        }
    }
    
    private func setupObservers() {
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] web, _ in
            DispatchQueue.main.async {
                let newTitle = web.title ?? ""
                self?.title = newTitle
                self?.parseUnreadCount(from: newTitle)
            }
        }
        
        loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] web, _ in
            DispatchQueue.main.async {
                self?.isLoading = web.isLoading
            }
        }
        
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
            DispatchQueue.main.async {
                self?.estimatedProgress = web.estimatedProgress
            }
        }
        
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] web, _ in
            DispatchQueue.main.async {
                self?.currentURL = web.url
            }
        }
        
        canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] web, _ in
            DispatchQueue.main.async {
                self?.canGoBack = web.canGoBack
            }
        }
        
        canGoForwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] web, _ in
            DispatchQueue.main.async {
                self?.canGoForward = web.canGoForward
            }
        }
    }
    
    private func parseUnreadCount(from title: String) {
        let oldCount = pageTitleUnreadCount
        // Many web apps format titles as "(N) Messenger" or "(N) Alice: Hello"
        guard title.hasPrefix("(") else {
            pageTitleUnreadCount = 0
            return
        }
        if let closeParenIndex = title.firstIndex(of: ")") {
            let start = title.index(after: title.startIndex)
            let countString = String(title[start..<closeParenIndex])
            if let count = Int(countString) {
                pageTitleUnreadCount = count
                
                // If unread count increased, notify listeners
                if count > oldCount {
                    let remainder = String(title[title.index(after: closeParenIndex)...]).trimmingCharacters(in: .whitespaces)
                    DispatchQueue.main.async { [weak self] in
                        self?.onTitleNotificationTriggered?(count, remainder)
                    }
                }
                return
            }
        }
        pageTitleUnreadCount = 0
    }
    
    // MARK: - WKScriptMessageHandler
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "islandNotification",
              let dict = message.body as? [String: Any] else { return }
        
        let title = dict["title"] as? String ?? ""
        let body = dict["body"] as? String ?? ""
        let icon = dict["icon"] as? String
        
        DispatchQueue.main.async { [weak self] in
            self?.onNotificationReceived?(title, body, icon)
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isLoading = false
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.isLoading = false
    }
    
    // Handle external links (target="_blank" or window.open)
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            // Open external link in system default browser
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}

// MARK: - SwiftUI NSViewRepresentable Host

public struct IslandWebViewHost: NSViewRepresentable {
    @ObservedObject public var controller: IslandWebController
    
    public init(controller: IslandWebController) {
        self.controller = controller
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        return controller.webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        // Controller manages view directly
    }
}
