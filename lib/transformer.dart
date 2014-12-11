// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:barback/barback.dart';

import 'async_await.dart';

/// A [Transformer] that runs the async/await compiler on any .dart files it
/// finds.
class AsyncAwaitTransformer extends Transformer implements LazyTransformer {
  AsyncAwaitTransformer.asPlugin();

  String get allowedExtensions => ".dart";

  void declareOutputs(DeclaringTransform transform) {
    // Just transforms a Dart file in place.
    transform.declareOutput(transform.primaryId);
  }

  Future apply(Transform transform) {
    return transform.primaryInput.readAsString().then((source) {
      source =
          compile(source, transform.primaryInput.id.path, Platform.packageRoot);
      transform.addOutput(
          new Asset.fromString(transform.primaryInput.id, source));
    });
  }
}
