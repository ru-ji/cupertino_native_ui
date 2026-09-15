import 'package:flutter/material.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import 'app.dart';
import 'scaffold_routes.dart';

void main() {
  if (CupertinoNativePageScaffold.maybeRun(scaffoldRoutes())) return;
  runApp(const MyApp());
  // Warm the shared engine group AND fully pre-boot the scaffold demo's
  // first tab ('home'): without listing it, bodies still boot lazily on
  // first visit — the plain prewarm() only pays the engine-group cold
  // start. Other routes stay lazy (each listed route costs startup time
  // and holds memory).
  CupertinoNativePageScaffold.prewarm(routes: ['home']);
}
