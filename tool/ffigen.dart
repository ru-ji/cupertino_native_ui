// Regenerates lib/src/internal/native_interop_bindings.g.dart from
// the CNUNativeInterop header under the cupertino_native_ui_objc SwiftPM target. Run: dart run tool/ffigen.dart
import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final root = Platform.script.resolve('../');
  final objc = root.resolve('ios/cupertino_native_ui/Sources/cupertino_native_ui_objc/');
  final generator = FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: root.resolve('lib/src/internal/native_interop_bindings.g.dart'),
      ),
      // Block trampolines: compiled into the plugin by SwiftPM.
      objectiveCFile: objc.resolve('native_interop_bindings.m'),
    ),
    input: Input(
      entryPoints: [objc.resolve('include/native_interop.h')],
    ),
    objectiveC: ObjectiveC(),
    visitors: [
      Visitor(
        objCInterface: (node) => node.isIncluded = node.name == 'CNUNativeInterop',
      ),
    ],
  );
  await generator.generate();
}
