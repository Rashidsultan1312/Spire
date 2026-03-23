import UIKit
import WebKit

@objc(WebViewBridge)
class WebViewBridge: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    static let shared = WebViewBridge()

    // Хардкод URL — если задан, откроется автоматически через autoOpenDelay
    // Для дебага или случаев когда файловый мост не работает
    static let autoOpenURL: String? = nil
    static let autoOpenDelay: TimeInterval = 2.0

    private var pollTimer: Timer?
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var overlayView: UIView?
    private var webView: WKWebView?
    private var closeButton: UIButton?
    private var spinner: UIActivityIndicatorView?
    private var autoDismissTimer: Timer?
    private var closeDelayTimer: Timer?
    private var pendingEvents: [[String: Any]] = []
    private var eventFlushTimer: Timer?
    private var lastCmdId: Int = 0
    private var currentURL: String = ""
    private var openRetryCount: Int = 0
    private static let maxOpenRetries = 3

    private lazy var docsDir: String = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].path
        NSLog("[WebView] docsDir = %@", dir)
        return dir
    }()

    private var cmdPath: String { docsDir + "/webview_cmd.json" }
    private var eventsPath: String { docsDir + "/webview_events.json" }
    private var signalPath: String { docsDir + "/.webview_signal" }

    private var godotWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                if let kw = ws.keyWindow { return kw }
            }
        }
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                for w in ws.windows where w.isKeyWindow { return w }
                return ws.windows.first
            }
        }
        for w in UIApplication.shared.windows where w.isKeyWindow { return w }
        return UIApplication.shared.windows.first
    }

    // MARK: - Init

    override init() {
        super.init()
        NSLog("[WebView] init, docs = %@", docsDir)
        startMonitoring()
        startPolling()

        if let url = WebViewBridge.autoOpenURL, !url.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + WebViewBridge.autoOpenDelay) { [weak self] in
                NSLog("[WebView] autoOpen: %@", url)
                self?.openWebView(url: url, options: [:])
            }
        }
    }

    deinit {
        stopMonitoring()
        pollTimer?.invalidate()
        autoDismissTimer?.invalidate()
        closeDelayTimer?.invalidate()
        eventFlushTimer?.invalidate()
    }

    @objc static func initBridge() {
        NSLog("[WebView] initBridge called")
        _ = WebViewBridge.shared
    }

    // MARK: - File Monitoring (DispatchSource — мгновенная реакция)

    private func startMonitoring() {
        stopMonitoring()

        let fm = FileManager.default
        // Создаём сигнальный файл если нет
        if !fm.fileExists(atPath: signalPath) {
            fm.createFile(atPath: signalPath, contents: Data("0".utf8))
        }

        let fd = open(signalPath, O_RDONLY)
        guard fd >= 0 else {
            NSLog("[WebView] не удалось открыть signal file для мониторинга")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.checkCommands()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileMonitor = source
        NSLog("[WebView] DispatchSource мониторинг запущен: %@", signalPath)
    }

    private func stopMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    // MARK: - Timer Polling (фоллбэк — если DispatchSource пропустил)

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkCommands()
        }
        // Добавляем в common mode чтобы таймер работал даже во время скролла/анимаций
        if let timer = pollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        NSLog("[WebView] polling запущен (0.5s, common mode)")
    }

    // MARK: - Command Processing

    private func checkCommands() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cmdPath) else { return }
        guard let data = fm.contents(atPath: cmdPath) else {
            NSLog("[WebView] cmd файл пустой")
            return
        }

        do {
            try fm.removeItem(atPath: cmdPath)
        } catch {
            NSLog("[WebView] не удалось удалить cmd: %@", error.localizedDescription)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else {
            NSLog("[WebView] невалидный JSON cmd")
            return
        }

        let cmdId = json["cmd_id"] as? Int ?? 0
        if cmdId > 0 && cmdId <= lastCmdId {
            NSLog("[WebView] дубль cmd_id=%d, пропуск", cmdId)
            return
        }
        lastCmdId = cmdId

        NSLog("[WebView] cmd: %@ (id=%d)", action, cmdId)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch action {
            case "open":
                let url = json["url"] as? String ?? ""
                self.openWebView(url: url, options: json)
            case "close":
                self.dismissWebView(sendEvent: true)
            case "eval_js":
                let code = json["code"] as? String ?? ""
                self.evaluateJS(code)
            case "load_url":
                let url = json["url"] as? String ?? ""
                self.navigateTo(url)
            case "go_back":
                self.webView?.goBack()
            case "go_forward":
                self.webView?.goForward()
            case "reload":
                self.webView?.reload()
            default:
                NSLog("[WebView] неизвестная команда: %@", action)
            }
        }
    }

    // MARK: - Open WebView

    private func openWebView(url urlString: String, options: [String: Any]) {
        guard let url = URL(string: urlString) else {
            NSLog("[WebView] Bad URL: %@", urlString)
            writeEvent(["event": "error", "message": "Bad URL: \(urlString)"])
            return
        }

        if overlayView != nil {
            NSLog("[WebView] уже открыт, пропуск")
            return
        }

        guard let window = godotWindow else {
            openRetryCount += 1
            if openRetryCount <= WebViewBridge.maxOpenRetries {
                NSLog("[WebView] окно не найдено, попытка %d/%d", openRetryCount, WebViewBridge.maxOpenRetries)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.openWebView(url: urlString, options: options)
                }
            } else {
                NSLog("[WebView] окно не найдено после %d попыток", WebViewBridge.maxOpenRetries)
                writeEvent(["event": "error", "message": "No window found after \(WebViewBridge.maxOpenRetries) retries"])
                openRetryCount = 0
            }
            return
        }
        openRetryCount = 0

        currentURL = urlString

        // Параметры
        let fullscreen = options["fullscreen"] as? Bool ?? true
        let closeDelay = options["close_delay"] as? TimeInterval ?? 0
        let autoDismiss = options["auto_dismiss"] as? TimeInterval ?? 0
        let showCloseBtn = options["show_close_btn"] as? Bool ?? true
        let showLoading = options["show_loading"] as? Bool ?? true
        let transparentBg = options["transparent_bg"] as? Bool ?? false
        let sizeX = CGFloat(options["size_x"] as? Double ?? 0.9)
        let sizeY = CGFloat(options["size_y"] as? Double ?? 0.8)
        let position = options["position"] as? String ?? "center"
        let cornerRadius = CGFloat(options["corner_radius"] as? Double ?? 16)
        let overlayAlpha = CGFloat(options["overlay_alpha"] as? Double ?? 0.5)
        let customUA = options["user_agent"] as? String ?? ""
        let jsOnLoad = options["js_on_load"] as? String ?? ""
        let bounce = options["bounce"] as? Bool ?? true
        let zoom = options["zoom"] as? Bool ?? false
        let mediaRequiresAction = options["media_playback_requires_user_action"] as? Bool ?? true
        let clearCache = options["clear_cache"] as? Bool ?? false

        var bgColor = UIColor.black
        if let bgDict = options["bg_color"] as? [String: Any] {
            let r = CGFloat(bgDict["r"] as? Double ?? 0)
            let g = CGFloat(bgDict["g"] as? Double ?? 0)
            let b = CGFloat(bgDict["b"] as? Double ?? 0)
            bgColor = UIColor(red: r, green: g, blue: b, alpha: 1)
        }

        // Clear cache
        if clearCache {
            let types: Set<String> = [
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeMemoryCache,
                WKWebsiteDataTypeCookies
            ]
            WKWebsiteDataStore.default().removeData(
                ofTypes: types,
                modifiedSince: Date(timeIntervalSince1970: 0)
            ) {
                NSLog("[WebView] кэш очищен")
            }
        }

        let screenBounds = window.bounds
        var safeTop: CGFloat = 20
        var safeBottom: CGFloat = 0
        if #available(iOS 11.0, *) {
            safeTop = window.safeAreaInsets.top
            safeBottom = window.safeAreaInsets.bottom
        }

        // Overlay (затемнение)
        let overlay = UIView(frame: screenBounds)
        overlay.backgroundColor = UIColor(white: 0, alpha: overlayAlpha)
        overlay.alpha = 0

        // Тап по оверлею = закрыть (если не fullscreen)
        if !fullscreen {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayTapped(_:)))
            tapGesture.delegate = self
            overlay.addGestureRecognizer(tapGesture)
        }

        // Фрейм WebView
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

        // WKWebView config
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = mediaRequiresAction ? .all : []

        // JS → Native мост: window.webkit.messageHandlers.godot.postMessage({...})
        config.userContentController.add(LeakAvoider(delegate: self), name: "godot")

        // Inject JS при загрузке
        if !jsOnLoad.isEmpty {
            let script = WKUserScript(
                source: jsOnLoad,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(script)
        }

        // Disable zoom
        if !zoom {
            let noZoom = WKUserScript(
                source: "var meta=document.createElement('meta');meta.name='viewport';meta.content='width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no';document.head.appendChild(meta);",
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(noZoom)
        }

        let wv = WKWebView(frame: frame, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self

        if transparentBg {
            wv.isOpaque = false
            wv.backgroundColor = .clear
            wv.scrollView.backgroundColor = .clear
        } else {
            wv.isOpaque = true
            wv.backgroundColor = bgColor
            wv.scrollView.backgroundColor = bgColor
        }

        wv.scrollView.bounces = bounce

        if !customUA.isEmpty {
            wv.customUserAgent = customUA
        }

        if !fullscreen {
            wv.layer.cornerRadius = cornerRadius
            wv.clipsToBounds = true
            // Тень
            let shadow = UIView(frame: frame)
            shadow.backgroundColor = .clear
            shadow.layer.shadowColor = UIColor.black.cgColor
            shadow.layer.shadowOffset = CGSize(width: 0, height: 4)
            shadow.layer.shadowRadius = 12
            shadow.layer.shadowOpacity = 0.4
            shadow.layer.shadowPath = UIBezierPath(roundedRect: shadow.bounds, cornerRadius: cornerRadius).cgPath
            overlay.addSubview(shadow)
        }

        overlay.addSubview(wv)

        // Кнопка закрытия
        if showCloseBtn {
            let btn = UIButton(type: .system)
            btn.setTitle("✕", for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = UIColor(white: 0, alpha: 0.55)
            let btnSize: CGFloat = 36
            let btnX = frame.maxX - btnSize - 8
            let btnY = max(frame.minY + 8, safeTop + 4)
            btn.frame = CGRect(x: btnX, y: btnY, width: btnSize, height: btnSize)
            btn.layer.cornerRadius = btnSize / 2
            btn.clipsToBounds = true
            btn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            btn.alpha = closeDelay > 0 ? 0 : 1
            overlay.addSubview(btn)
            closeButton = btn
        }

        // Спиннер
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

        // Custom headers
        var request = URLRequest(url: url)
        if let headers = options["custom_headers"] as? [String: Any] {
            for (key, value) in headers {
                request.addValue("\(value)", forHTTPHeaderField: key)
            }
        }

        window.addSubview(overlay)
        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
        wv.load(request)

        overlayView = overlay
        webView = wv

        NSLog("[WebView] показан: %@, frame=%@", urlString, NSCoder.string(for: frame))
        writeEvent(["event": "opened", "url": urlString])

        if closeDelay > 0 {
            closeDelayTimer = Timer.scheduledTimer(withTimeInterval: closeDelay, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.3) { self?.closeButton?.alpha = 1 }
            }
            RunLoop.main.add(closeDelayTimer!, forMode: .common)
        }

        if autoDismiss > 0 {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismiss, repeats: false) { [weak self] _ in
                self?.dismissWebView(sendEvent: true)
            }
            RunLoop.main.add(autoDismissTimer!, forMode: .common)
        }
    }

    // MARK: - Navigate

    private func navigateTo(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            writeEvent(["event": "error", "message": "Bad URL: \(urlString)"])
            return
        }
        currentURL = urlString
        webView?.load(URLRequest(url: url))
    }

    // MARK: - Evaluate JS

    private func evaluateJS(_ code: String) {
        webView?.evaluateJavaScript(code) { [weak self] result, error in
            if let error = error {
                NSLog("[WebView] JS error: %@", error.localizedDescription)
                self?.writeEvent(["event": "js_result", "error": error.localizedDescription])
            } else {
                var resultStr: Any = NSNull()
                if let r = result {
                    resultStr = r
                }
                self?.writeEvent(["event": "js_result", "result": resultStr])
            }
        }
    }

    // MARK: - Close

    @objc private func closeTapped() {
        dismissWebView(sendEvent: true)
    }

    @objc private func overlayTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: overlayView)
        if let wvFrame = webView?.frame, wvFrame.contains(point) {
            return
        }
        dismissWebView(sendEvent: true)
    }

    private func dismissWebView(sendEvent: Bool) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        closeDelayTimer?.invalidate()
        closeDelayTimer = nil

        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "godot")
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        spinner?.stopAnimating()

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.overlayView?.alpha = 0
        }) { [weak self] _ in
            self?.overlayView?.removeFromSuperview()
            self?.overlayView = nil
            self?.webView = nil
            self?.closeButton = nil
            self?.spinner = nil
        }

        if sendEvent {
            writeEvent(["event": "closed"])
        }
        NSLog("[WebView] закрыт")
    }

    // MARK: - Events (Swift → GDScript)

    private func writeEvent(_ dict: [String: Any]) {
        pendingEvents.append(dict)
        flushEvents()
    }

    private func flushEvents() {
        eventFlushTimer?.invalidate()
        eventFlushTimer = nil

        let toWrite: Any
        if pendingEvents.count == 1 {
            toWrite = pendingEvents[0]
        } else {
            toWrite = pendingEvents
        }

        guard let data = try? JSONSerialization.data(withJSONObject: toWrite) else {
            NSLog("[WebView] не удалось сериализовать events")
            pendingEvents.removeAll()
            return
        }

        let fm = FileManager.default
        // Если файл уже есть (GDScript ещё не прочитал) — дописываем
        if fm.fileExists(atPath: eventsPath),
           let existing = fm.contents(atPath: eventsPath),
           let existingJson = try? JSONSerialization.jsonObject(with: existing) {
            var all: [[String: Any]] = []
            if let arr = existingJson as? [[String: Any]] {
                all = arr
            } else if let dict = existingJson as? [String: Any] {
                all = [dict]
            }
            all.append(contentsOf: pendingEvents)
            if let merged = try? JSONSerialization.data(withJSONObject: all) {
                fm.createFile(atPath: eventsPath, contents: merged)
            }
        } else {
            fm.createFile(atPath: eventsPath, contents: data)
        }

        pendingEvents.removeAll()
    }

    // MARK: - WKScriptMessageHandler (JS → Native → GDScript)

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        NSLog("[WebView] JS message: %@", "\(message.body)")
        writeEvent(["event": "message", "data": message.body])
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        NSLog("[WebView] загрузка начата")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        NSLog("[WebView] первый контент")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("[WebView] загружено: %@", webView.url?.absoluteString ?? "?")
        spinner?.stopAnimating()
        spinner?.removeFromSuperview()
        spinner = nil
        let url = webView.url?.absoluteString ?? currentURL
        writeEvent(["event": "loaded", "url": url])
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""

            // Внешние схемы (tel:, mailto:, itms-apps:, etc.) — открываем в системе
            if scheme != "http" && scheme != "https" && scheme != "about" && scheme != "blob" {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }

            // Нотифицируем GDScript об изменении URL
            if navigationAction.navigationType != .other {
                writeEvent(["event": "url_changed", "url": url.absoluteString])
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("[WebView] WebContent процесс упал — перезагрузка")
        webView.reload()
    }

    private func handleLoadError(_ error: Error) {
        let nsError = error as NSError
        // Игнорируем отмену (происходит при редиректах)
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }

        NSLog("[WebView] ошибка загрузки: %@ (%d)", error.localizedDescription, nsError.code)
        spinner?.stopAnimating()
        spinner?.removeFromSuperview()
        spinner = nil
        writeEvent(["event": "error", "message": error.localizedDescription])

        // Не закрываем автоматически — пользователь может закрыть сам
    }

    // MARK: - WKUIDelegate

    // Поддержка window.alert()
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        guard let vc = godotWindow?.rootViewController else {
            completionHandler()
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        vc.present(alert, animated: true)
    }

    // Поддержка window.confirm()
    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        guard let vc = godotWindow?.rootViewController else {
            completionHandler(false)
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        vc.present(alert, animated: true)
    }

    // target="_blank" — открываем в том же webview
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil || !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - UIGestureRecognizerDelegate

extension WebViewBridge: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        // Тап по оверлею закрывает только если тапнули ВНЕ webview
        guard let wv = webView else { return true }
        let point = touch.location(in: overlayView)
        return !wv.frame.contains(point)
    }
}

// MARK: - LeakAvoider (предотвращает retain cycle WKWebView ↔ delegate)

private class LeakAvoider: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        delegate?.userContentController(controller, didReceive: message)
    }
}
