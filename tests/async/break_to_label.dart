test0() async {
  here: {
    var x = 0;
    break here;
  }
  print("bye");
}

test1() async {
here: {
  var x = 0;
  while(true) {
     x = x+1;
     if(x > 10) break;
  }
  print("broke");
}
print("bye");
}

test2() async {
  var x = 0;
  here: while(true) {
     x = x+1;
     if(x > 10) { break; }
     if(x > 20) { break here; }
   }
   print("bye");
}

test2() async {
  var x = 0;
  here: do {
    x = x+1;
    if(x > 10) { break; }
    if(x > 20) { break here; }
  } while(true);
  print("bye");
}

test3() async {
  here: for(var x = 0; x < 100; x = x+1) {
    if(x > 10) { break; }
    if(x > 20) { break here; }
  }
  print("bye");
}