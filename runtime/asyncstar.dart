import 'dart:async';

/**
 * _onListen is set to the translation of the async* body
 * _onResume is mutated whenever the stream is paused.
 * onCancel will set isCancelled so that we can check that we are cancelled.
 * No need to specialize onPaused, the underlying _controller will set isPaused for us.
 */
class _StreamController<T> implements StreamController<T> {

  var _onListen = (){};
  void onListen() { _onListen(); }

  var _onResume = (){};
  void onResume(){ _onResume(); }

  bool isCancelled = false;
  Future onCancel() {
    isCancelled = true;
    return close(); // close stream to make sure no further values can be added.
  }

  StreamController<T> _controller;
  _StreamController() {
    _controller = new StreamController(onListen: onListen, onResume: onResume, onCancel: onCancel);
  }

  // delegate all methods to _controller
  add(T event){ _controller.add(event); }
  void addError(Object error, [StackTrace stackTrace]){ _controller.add(error, stackTrace); }
  Future addStream(Stream<T> source, {bool cancelOnError: true}) { _controller.addStream(source, cancelOnError); }
  Future close() { _controller.close(); }

  // delegate all properties to _controller
  Future get done        => _controller.done;
  bool get hasListener   => _controller.hasListener;
  bool get isClosed      => _controller.isClosed;
  bool get isPaused      => _controller.isPaused;
  StreamSink<T> get sink => _controller.sink;
  Stream<T> get stream   => _controller.stream;
}