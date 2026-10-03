import 'dart:async';

import 'package:app/core/astro_engine.dart';
import 'package:app/core/fake_astro_engine.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AstroEngine.defaultFactory = () => FakeAstroEngine();
  await testMain();
}
