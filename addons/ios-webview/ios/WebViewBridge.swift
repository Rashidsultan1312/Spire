import UIKit
import WebKit

@objc(WebViewBridge) class WebViewBridge: NSObject, WKNavigationDelegate {

    static let shared = WebViewBridge()

    static let autoOpenURL: String? = nil
    static let autoOpenDelay: TimeInterval = 2.0

    private var pollTimer: Timer?
    private var overlayView: UIView?
    private var webView: WKWebView?
    private var closeButton: UIButton?
    private var spinner: UIActivityIndicatorView?
    private var autoDismissTimer: Timer?
    private var closeDelayTimer: Timer?

    private var docsDir: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
    }
    private var cmdPath: String { docsDir + "/webview_cmd.json" }
    private var eventsPath: String { docsDir + "/webview_events.json" }

    private var godotWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                if #available(iOS 15.0, *) {
                    if let kw = ws.keyWindow { return kw }
                }
                for w in ws.windows where w.isKeyWindow { return w }
                return ws.windows.first
            }
        }
        #if swift(>=5.1)
        if #available(iOS 15.0, *) {
        } else {
            for w in UIApplication.shared.windows where w.isKeyWindow { return w }
            return UIApplication.shared.windows.first
        }
        #endif
        return nil
    }

    override init() {
        super.init()
        NSLog("[WebView] init — путь: %@", docsDir)
        startPolling()
        if let url = WebViewBridge.autoOpenURL {
            DispatchQueue.main.asyncAfter(deadline: .now() + WebViewBridge.autoOpenDelay) { [weak self] in
                self?.openWebView(url: url, options: [:])
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
        autoDismissTimer?.invalidate()
        closeDelayTimer?.invalidate()
    }

    @objc static func initBridge() {
        NSLog("[WebView] initBridge")
        _ = WebViewBridge.shared
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkCommands()
        }
    }

    private func checkCommands() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cmdPath) else { return }

        guard let data = fm.contents(atPath: cmdPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else {
            NSLog("[WebView] не удалось прочитать JSON")
            return
        }

        try? fm.removeItem(atPath: cmdPath)

        DispatchQueue.main.async { [weak self] in
            switch action {
            case "open":
                let url = json["url"] as? String ?? ""
                NSLog("[WebView] open %@", url)
                self?.openWebView(url: url, options: json)
            case "close":
                NSLog("[WebView] close")
                self?.dismissWebView(sendEvent: true)
            default:
                break
            }
        }
    }

    // MARK: - Open

    private func openWebView(url urlString: String, options: [String: Any]) {
        guard let url = URL(string: urlString) else {
            writeEvent(["event": "error", "message": "Bad URL: \(urlString)"])
            return
        }

        if overlayView != nil {
            NSLog("[WebView] уже открыт")
            return
        }

        guard let window = godotWindow else {
            NSLog("[WebView] окно не найдено")
            writeEvent(["event": "error", "message": "No window"])
            return
        }

        let closeDelay = options["close_delay"] as? TimeInterval ?? 0
        let autoDismiss = options["auto_dismiss"] as? TimeInterval ?? 0
        let fullscreen = options["fullscreen"] as? Bool ?? true
        let showLoading = options["show_loading"] as? Bool ?? true
        let bgR = CGFloat(options["bg_r"] as? Double ?? 0)
        let bgG = CGFloat(options["bg_g"] as? Double ?? 0)
        let bgB = CGFloat(options["bg_b"] as? Double ?? 0)
        let sizeX = CGFloat(options["size_x"] as? Double ?? 0.9)
        let sizeY = CGFloat(options["size_y"] as? Double ?? 0.7)
        let position = options["position"] as? String ?? "center"

        let screenBounds = window.bounds
        var safeTop: CGFloat = 20
        var safeBottom: CGFloat = 0
        if #available(iOS 11.0, *) {
            safeTop = window.safeAreaInsets.top
            safeBottom = window.safeAreaInsets.bottom
        }

        let overlay = UIView(frame: screenBounds)
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.6)
        overlay.alpha = 0

        var frame = screenBounds
        if !fullscreen {
            let w = screenBounds.width * sizeX
            let h = screenBounds.height * sizeY
            let x = (screenBounds.width - w) / 2
            var y: CGFloat
            switch position {
            case "top": y = safeTop + 10
            case "bottom": y = screenBounds.height - h - safeBottom - 10
            default: y = (screenBounds.height - h) / 2
            }
            frame = CGRect(x: x, y: y, width: w, height: h)
        }

        let bgColor = UIColor(red: bgR, green: bgG, blue: bgB, alpha: 1)
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let wv = WKWebView(frame: frame, configuration: config)
        wv.navigationDelegate = self
        wv.backgroundColor = bgColor
        wv.scrollView.backgroundColor = bgColor
        wv.isOpaque = true
        if !fullscreen {
            wv.layer.cornerRadius = 12
            wv.clipsToBounds = true
        }
        overlay.addSubview(wv)

        let btn = UIButton(type: .system)
        btn.setTitle("✕", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(white: 0, alpha: 0.6)
        let btnSize: CGFloat = 44
        btn.frame = CGRect(
            x: frame.maxX - btnSize - 12,
            y: max(frame.minY + 12, safeTop + 8),
            width: btnSize, height: btnSize
        )
        btn.layer.cornerRadius = btnSize / 2
        btn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        btn.alpha = closeDelay > 0 ? 0 : 1
        overlay.addSubview(btn)

        if showLoading {
            let sp: UIActivityIndicatorView
            if #available(iOS 13.0, *) {
                sp = UIActivityIndicatorView(style: .large)
            } else {
                sp = UIActivityIndicatorView(style: .whiteLarge)
            }
            sp.color = .white
            sp.center = CGPoint(x: frame.midX, y: frame.midY)
            sp.startAnimating()
            overlay.addSubview(sp)
            spinner = sp
        }

        pollTimer?.invalidate()
        pollTimer = nil

        window.addSubview(overlay)
        NSLog("[WebView] показан, загружаю %@", url.absoluteString)

        UIView.animate(withDuration: 0.3) { overlay.alpha = 1 }
        wv.load(URLRequest(url: url))

        overlayView = overlay
        webView = wv
        closeButton = btn

        if closeDelay > 0 {
            closeDelayTimer = Timer.scheduledTimer(withTimeInterval: closeDelay, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.3) { self?.closeButton?.alpha = 1 }
            }
        }

        if autoDismiss > 0 {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismiss, repeats: false) { [weak self] _ in
                self?.dismissWebView(sendEvent: true)
            }
        }
    }

    // MARK: - Close

    @objc private func closeTapped() {
        dismissWebView(sendEvent: true)
    }

    private func dismissWebView(sendEvent: Bool) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        closeDelayTimer?.invalidate()
        closeDelayTimer = nil

        webView?.stopLoading()
        webView?.navigationDelegate = nil
        spinner?.stopAnimating()

        UIView.animate(withDuration: 0.25, animations: { [weak self] in
            self?.overlayView?.alpha = 0
        }) { [weak self] _ in
            self?.overlayView?.removeFromSuperview()
            self?.overlayView = nil
            self?.webView = nil
            self?.closeButton = nil
            self?.spinner = nil
            NSLog("[WebView] закрыт")
        }

        if sendEvent {
            writeEvent(["event": "closed"])
        }

        startPolling()
    }

    // MARK: - Events

    private func writeEvent(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        FileManager.default.createFile(atPath: eventsPath, contents: data)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        NSLog("[WebView] загрузка началась")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        NSLog("[WebView] первый контент получен")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("[WebView] страница загружена")
        spinner?.stopAnimating()
        spinner?.removeFromSuperview()
        spinner = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("[WebView] WebContent процесс упал — перезагружаю")
        webView.reload()
    }

    private func handleLoadError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            NSLog("[WebView] загрузка отменена (редирект)")
            return
        }
        NSLog("[WebView] ошибка: %@ (код %d)", error.localizedDescription, nsError.code)
        spinner?.stopAnimating()
        spinner?.removeFromSuperview()
        spinner = nil
        writeEvent(["event": "error", "message": error.localizedDescription])
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.dismissWebView(sendEvent: true)
        }
    }
}
