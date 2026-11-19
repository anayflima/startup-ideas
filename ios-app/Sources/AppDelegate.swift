import UIKit
import WebKit

let homeURL = URL(string: "https://anayflima.github.io/startup-ideas/hours/")!

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = WebViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var web: WKWebView!
    private let bg = UIColor(red: 12/255, green: 13/255, blue: 24/255, alpha: 1)

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func loadView() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        cfg.applicationNameForUserAgent = "PavootHoursApp/1.0 (iOS)"
        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = bg
        web.scrollView.backgroundColor = bg
        web.scrollView.contentInsetAdjustmentBehavior = .never
        let rc = UIRefreshControl()
        rc.tintColor = .white
        rc.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        web.scrollView.refreshControl = rc
        view = web
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        web.load(URLRequest(url: homeURL))
    }

    @objc private func pullToRefresh() {
        if web.url == nil { web.load(URLRequest(url: homeURL)) } else { web.reload() }
        web.scrollView.refreshControl?.endRefreshing()
    }

    private func isInside(_ u: URL) -> Bool {
        guard u.host == "anayflima.github.io" else { return false }
        let p = u.path
        return p.hasPrefix("/startup-ideas/hours") && !p.hasSuffix(".apk") && !p.hasSuffix(".mjs")
    }

    // MARK: navigation
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let u = navigationAction.request.url else { decisionHandler(.allow); return }
        let scheme = u.scheme ?? ""
        if ["about", "blob", "data"].contains(scheme) || isInside(u) || navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow); return
        }
        UIApplication.shared.open(u)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { showError(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { showError(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.load(URLRequest(url: homeURL)) }

    private func showError(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        guard presentedViewController == nil else { return }
        let a = UIAlertController(title: "Can't reach Pavoot Hours", message: "Check your internet connection and try again.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Try again", style: .default) { [weak self] _ in
            self?.web.load(URLRequest(url: homeURL))
        })
        present(a, animated: true)
    }

    // MARK: JavaScript dialogs (confirm() is used for delete / sign out)
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { [weak a] _ in completionHandler(a?.textFields?.first?.text) })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = navigationAction.request.url { UIApplication.shared.open(u) }
        return nil
    }
}
