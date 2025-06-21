import 'package:tson_dart/tson_dart.dart';

void main() {
  final result = tson.decode(
    'user{name"John", age#30, isActive?true, isAdmin?false, address{street"123 Main St", city"Anytown", zip"12345"}, friends<#>[10, 80 , 48]}',
  );
  print(result);
  print(result.runtimeType);
  print(result["user"]["friends"]);
  print(result["user"]["friends"].runtimeType);
}
