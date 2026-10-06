import Foundation

/// Tagged native-side logging.
///
/// Every line carries a stable prefix and the call site, so the output of
/// `flutter run` / `flutter logs` can be grepped for the subsystem of
/// interest (`grep cupertino_native_ui`). Leave these in: the keyboard accessory
/// in particular is hard to observe from outside, and the log is the fastest
/// way to debug a focus/toolbar cycle.
///
/// Debug builds only: in a release app every focus change, window move and
/// toolbar rebuild would still format a string and go through `NSLog`.
enum NativeLog {
    /// `@autoclosure` so a release build never even builds the string.
    static func log(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        #if DEBUG
        NSLog("[cupertino_native_ui] %@  [%@:%d]", message(), file, line)
        #endif
    }
}
