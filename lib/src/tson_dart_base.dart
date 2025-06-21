import 'dart:convert';

import 'package:tson_dart/src/parser.dart';

class TsonCodec extends Codec<dynamic, String> {
  @override
  Converter<String, dynamic> get decoder => TsonDecoder();

  @override
  Converter<dynamic, String> get encoder => throw UnimplementedError();
}

class TsonDecoder extends Converter<String, dynamic> {
  @override
  dynamic convert(String input) {
    return Parser().parse(input);
  }
}

final tson = TsonCodec();
