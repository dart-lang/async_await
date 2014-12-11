// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'src/compiler.dart';

/// Given [source], a string of Dart code which may contain async/await syntax,
/// compiles it down to raw Dart 1.0 syntax.
///
/// [path] can be relative or absolute.  It is used for error reporting.
String compile(String source, String path, String packageRoot) {
  return Compiler.compile(source, path, packageRoot, (errorCollector) {
    throw new FormatException(
        "Compilation error:\n${errorCollector.errors.join("\n")}");
  });
}
