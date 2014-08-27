import 'dart:async';

f(n) async => n;

test0() async {
   print("a");
   var x = await f(10);
   print(x);
}

test1() async {
  var z = await f(await f(10));
}
