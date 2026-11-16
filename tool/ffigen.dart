// Regenerates lib/src/internal/native_interop_bindings.g.dart from
// tool/ffigen/native_interop.h. Run: dart run tool/ffigen.dart
import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final root = Platform.script.resolve('../');
  final generator = FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: root.resolve('lib/src/internal/native_interop_bindings.g.dart'),
      ),
    ),
    input: Input(
      entryPoints: [root.resolve('tool/ffigen/native_interop.h')],
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
