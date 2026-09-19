import Foundation

/// Tagged native-side logging.
///
/// Every line carries a stable prefix and the call site, so the output of
/// `flutter run` / `flutter logs` can be grepped for the subsystem of
/// interest (`grep cupertino_widgets`). Leave these in: the keyboard accessory
/// in particular is hard to observe from outside, and the log is the fastest
/// way to debug a focus/toolbar cycle.
enum NativeLog {
    /// `@autoclosure` so a caller does not build strings when the message
    /// would be thrown away — though `NSLog` here always emits.
    static func log(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        NSLog("[cupertino_widgets] %@  [%@:%d]", message(), file, line)
    }
}