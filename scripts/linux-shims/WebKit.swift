// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `WebKit` n'existe pas sous Linux. Un seul appelant,
// `CourseDocumentHtmlView.swift` : `WKWebView` + pont `WKScriptMessageHandler`.
//
// `WKWebView` et `WKScriptMessage` dérivent de `UIView`/`NSObject` : c'est
// indispensable pour que `UIViewRepresentable` (`makeUIView(context:) ->
// WKWebView`) soit satisfait.
import Foundation
import UIKit

open class WKUserContentController: NSObject {
    public func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String) {}
    public func removeScriptMessageHandler(forName name: String) {}
    public func removeAllScriptMessageHandlers() {}
}

open class WKWebViewConfiguration: NSObject {
    public var userContentController: WKUserContentController = WKUserContentController()
}

open class WKScriptMessage: NSObject {
    public var name: String { "" }
    public var body: Any { "" }
    public var webView: WKWebView? { nil }
}

public protocol WKScriptMessageHandler: NSObjectProtocol {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    )
}

open class WKNavigation: NSObject {}

open class WKWebView: UIView {
    public init(frame: CGRect, configuration: WKWebViewConfiguration) { super.init() }
    public override init() { super.init() }

    public var configuration: WKWebViewConfiguration { WKWebViewConfiguration() }
    public var scrollView: UIScrollView { UIScrollView() }
    public var isLoading: Bool { false }
    public var title: String? { nil }

    @discardableResult
    public func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? { nil }

    public func stopLoading() {}
    public func reload() {}
}
