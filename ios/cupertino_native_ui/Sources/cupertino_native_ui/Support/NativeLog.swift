import Foundation

/// The package's own diagnostics.
///
/// Off unless the app is run with `CUPERTINO_NATIVE_UI_LOG=1` in its
/// environment (Xcode: Product › Scheme › Edit Scheme › Run › Arguments ›
/// Environment Variables). They are for working on the package itself: an app
/// that only uses it never sees them, in a debug build or a release one.
/// Compiled out of release builds altogether.
///
/// Every line carries a stable prefix and the call site, so the output can be
/// grepped for the subsystem of interest (`grep cupertino_native_ui`). The
/// keyboard accessory in particular is hard to observe from outside, and the
/// log is the fastest way to debug a focus/toolbar cycle.
enum NativeLog {
    #if DEBUG
        static let enabled = ProcessInfo.processInfo.environment["CUPERTINO_NATIVE_UI_LOG"] == "1"
    #endif

    /// `@autoclosure` so a message that is not logged is never even built.
    static func log(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        #if DEBUG
            guard enabled else { return }
            NSLog("[cupertino_native_ui] %@  [%@:%d]", message(), file, line)
        #endif
    }
}
