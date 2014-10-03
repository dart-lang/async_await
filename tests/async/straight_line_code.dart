import 'dart:async';

printAsync(s) async {
   print(s);
}

main0() async {
  print("A");
  await printAsync("B");
  print("C");
  await printAsync("D");
  print("E");
}

main1() async {
   if(true) {
     await printAsync("A");
   } else {
     print("B");
   }
   print("C");
}

main2() async {
   while(true) {
     await printAsync("A");
   }
   print("B");
}

main3() async {
   try {
      print("A");
   } catch(e) {
     print("B");
   } finally {
     print("C");
   }
   print("D");
}
