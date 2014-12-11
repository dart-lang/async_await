#!/usr/bin/env dart

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';

import 'package:async_await/src/compiler.dart';

main(List<String> args) {
  var argParser = new ArgParser(allowTrailingOptions: true);
  argParser.addOption('package-root', help: 'The path to the package root',
      defaultsTo: Platform.packageRoot);
  var result = argParser.parse(args);
  if (result.rest.length != 1) {
    print('Usage: async_await.dart [file]');
    print('  Options: --package-root=[path]  The path to the package root');
    exit(0);
  }
  var file = new File(result.rest.first);
  var source = file.readAsStringSync();
  var output = Compiler.compile(source, file.absolute.path,
      result['package-root'], (errorCollector) {
    print("Errors:");
    errorCollector.errors.forEach(print);
    exit(1);
  });
  print(output);
}
