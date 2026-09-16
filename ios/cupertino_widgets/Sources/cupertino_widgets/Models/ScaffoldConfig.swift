import Foundation

/// Creation/update parameters for the native scaffold platform view.
/// Body engines always boot the app's default `main()` with a
/// `cn-scaffold://<route>` initial route intercepted by
/// `CupertinoNativeScaffold.maybeRun` on the Dart side.
@available(iOS 26.0, *)
struct ScaffoldConfig: Codable {
    let body: String?  // root body route, used when tabBar == nil
    /// A body described from Dart and rendered as SwiftUI directly, instead
    /// of an embedded FlutterEngine. When set it replaces `body`/the tabs'
    /// engines entirely: no nested FlutterView, no platform views.
    let nativeBody: BodyNodeConfig?
    let appBar: AppBarConfig?
    let tabBar: TabBarConfig?
    let scrollEdgeEffect: String?  // "automatic" | "soft" | "hard" (iOS 26)
    let isDark: Bool?
    let backgroundColor: Int?  // ARGB — defaults to scaffoldBackgroundColor from Flutter theme
    let primaryColor: Int?     // ARGB — defaults to colorScheme.primary from Flutter theme
    let showLoadingIndicator: Bool?  // spinner while a body engine boots; nil = false
    /// False: the keyboard no longer pushes the content up. nil = true.
    var resizeToAvoidBottomInset: Bool? = nil
    /// True: dragging down over the keyboard dismisses it, following the
    /// finger (`.scrollDismissesKeyboard(.interactively)`). nil = false.
    var interactiveKeyboardDismiss: Bool? = nil
}
