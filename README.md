async-await transformer DEPRECATED
=======================

**Use Dart 1.9+ for [native support][doc] for async/await/sync*/async*/yield.**

A prototype (and in progress) implementation of async/await in Dart,
via CPS translation.

This transformer is useful for trying async/await with dart2js.
The Dart VM natively supports async and await. If you are writing
Dart code that runs only in the VM, you do not need this transformer.

## How to use

Add this to your pubspec.yaml file:

```
dependencies:
  async_await:
    git: https://github.com/dart-lang/async_await.git
transformers:
- async_await
```

Import dart:async in your Dart file:

```
import 'dart:async';
```

## What works

* async
* await
* await for

## What doesn't yet work

See also the [open issues][issues].

* Stack traces are not according to the spec

[doc]: https://www.dartlang.org/guides/language/language-tour#asynchrony-support
[issues]: https://github.com/dart-lang/async_await/issues
