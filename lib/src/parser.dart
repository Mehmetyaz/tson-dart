/// Single-pass TSON parser for Dart
/// This parser reads TSON input and directly produces Dart objects (Map, List, String, num, bool, null)
/// according to the TSON specification described in README.md. It does not use a separate lexer and parser.
///
/// Usage:
///   final result = TsonSinglePassParser().parse('user{name"John", age#30}');
///
/// Supports:
///   - Named/unnamed objects and arrays
///   - String, int, double, bool, null
///   - Type specifiers for arrays
///   - Nested structures
///   - Comments and whitespace are ignored
class Parser {
  late String _input;
  int _pos = 0;
  int _line = 1;
  int _col = 1;

  dynamic parse(String input) {
    _input = input;
    _pos = 0;
    _line = 1;
    _col = 1;
    _skipWhitespaceAndComments();
    final value = _parseValue(allowName: true);
    _skipWhitespaceAndComments();
    if (!_isAtEnd()) {
      throw _error('Unexpected trailing characters');
    }
    return value;
  }

  bool _isAtEnd() => _pos >= _input.length;
  String _peek() => _isAtEnd() ? '\u0000' : _input[_pos];
  String _peekNext() =>
      (_pos + 1 < _input.length) ? _input[_pos + 1] : '\u0000';
  String _advance() {
    final c = _peek();
    _pos++;
    if (c == '\n') {
      _line++;
      _col = 1;
    } else {
      _col++;
    }
    return c;
  }

  bool _match(String expected) {
    if (_peek() == expected) {
      _advance();
      return true;
    }
    return false;
  }

  void _skipWhitespaceAndComments() {
    while (!_isAtEnd()) {
      final c = _peek();
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        _advance();
      } else if (c == '/' && _peekNext() == '/') {
        // Line comment
        while (!_isAtEnd() && _peek() != '\n') _advance();
      } else if (c == '/' && _peekNext() == '*') {
        // Block comment
        _advance();
        _advance();
        while (!_isAtEnd() && !(_peek() == '*' && _peekNext() == '/')) {
          _advance();
        }
        if (!_isAtEnd()) {
          _advance();
          _advance();
        }
      } else {
        break;
      }
    }
  }

  dynamic _parseValue({bool allowName = false}) {
    _skipWhitespaceAndComments();
    if (_isAtEnd()) throw _error('Unexpected end of input');
    if (allowName && _isNameStart(_peek())) {
      final name = _parseName();
      _skipWhitespaceAndComments();
      final c = _peek();
      if (c == '{') {
        _advance();
        final obj = _parseObject();
        return {name: obj};
      } else if (c == '[') {
        _advance();
        final arr = _parseArray();
        return {name: arr};
      } else if (c == '<') {
        _advance();
        final type = _parseTypeSpecifier();
        if (_peek() != '[') throw _error('Expected [ after type specifier');
        _advance();
        final arr = _parseArray(typeSpecifier: type);
        return {name: arr};
      } else if (c == '"') {
        _advance();
        final str = _parseString();
        return {name: str};
      } else if (c == '#') {
        _advance();
        final num = _parseInt();
        return {name: num};
      } else if (c == '=') {
        _advance();
        final num = _parseDouble();
        return {name: num};
      } else if (c == '?') {
        _advance();
        final b = _parseBoolean();
        return {name: b};
      } else if (c == ',') {
        // name,null
        return {name: null};
      } else {
        // name (null)
        return {name: null};
      }
    }
    // Unnamed value
    final c = _peek();
    if (c == '{') {
      _advance();
      return _parseObject();
    } else if (c == '[') {
      _advance();
      return _parseArray();
    } else if (c == '<') {
      _advance();
      final type = _parseTypeSpecifier();
      if (_peek() != '[') throw _error('Expected [ after type specifier');
      _advance();
      return _parseArray(typeSpecifier: type);
    } else if (c == '"') {
      _advance();
      return _parseString();
    } else if (c == '#') {
      _advance();
      return _parseInt();
    } else if (c == '=') {
      _advance();
      return _parseDouble();
    } else if (c == '?') {
      _advance();
      return _parseBoolean();
    } else if (c == '-' && !_isDigit(_peekNext())) {
      _advance();
      return null; // undefined
    } else {
      throw _error('Unexpected character: $c');
    }
  }

  Map<String, dynamic> _parseObject() {
    final map = <String, dynamic>{};
    _skipWhitespaceAndComments();
    while (!_isAtEnd() && _peek() != '}') {
      _skipWhitespaceAndComments();
      if (!_isNameStart(_peek())) throw _error('Expected property name');
      final name = _parseName();
      _skipWhitespaceAndComments();
      final c = _peek();
      dynamic value;
      if (c == '{') {
        _advance();
        value = _parseObject();
      } else if (c == '[') {
        _advance();
        value = _parseArray();
      } else if (c == '<') {
        _advance();
        final type = _parseTypeSpecifier();
        if (_peek() != '[') throw _error('Expected [ after type specifier');
        _advance();
        value = _parseArray(typeSpecifier: type);
      } else if (c == '"') {
        _advance();
        value = _parseString();
      } else if (c == '#') {
        _advance();
        value = _parseInt();
      } else if (c == '=') {
        _advance();
        value = _parseDouble();
      } else if (c == '?') {
        _advance();
        value = _parseBoolean();
      } else if (c == ',') {
        value = null;
      } else {
        value = null;
      }
      map[name] = value;
      _skipWhitespaceAndComments();
      if (_peek() == ',') {
        _advance();
        _skipWhitespaceAndComments();
      } else {
        break;
      }
    }
    if (_peek() != '}') throw _error('Expected } at end of object');
    _advance();
    return map;
  }

  List<dynamic> _parseArray({String typeSpecifier = ''}) {
    final list = <dynamic>[];
    _skipWhitespaceAndComments();
    while (!_isAtEnd() && _peek() != ']') {
      _skipWhitespaceAndComments();
      final value = _parseValue(allowName: true);
      list.add(value);
      _skipWhitespaceAndComments();
      if (_peek() == ',') {
        _advance();
        _skipWhitespaceAndComments();
      } else {
        break;
      }
    }
    if (_peek() != ']') throw _error('Expected ] at end of array');
    _advance();
    return list;
  }

  String _parseName() {
    final sb = StringBuffer();
    if (!_isNameStart(_peek())) throw _error('Invalid name start');
    sb.write(_advance());
    while (_isNamePart(_peek())) {
      sb.write(_advance());
    }
    return sb.toString();
  }

  String _parseTypeSpecifier() {
    final sb = StringBuffer();
    while (_peek() != '>' && !_isAtEnd()) {
      sb.write(_advance());
    }
    if (_peek() != '>') throw _error('Expected > at end of type specifier');
    _advance();
    return sb.toString();
  }

  String _parseString() {
    final sb = StringBuffer();
    while (!_isAtEnd() && _peek() != '"') {
      final c = _advance();
      if (c == '\\') {
        final next = _advance();
        if (next == 'n')
          sb.write('\n');
        else if (next == 't')
          sb.write('\t');
        else if (next == 'r')
          sb.write('\r');
        else if (next == '"')
          sb.write('"');
        else if (next == '\\')
          sb.write('\\');
        else
          sb.write(next);
      } else {
        sb.write(c);
      }
    }
    if (_peek() != '"') throw _error('Unterminated string');
    _advance();
    return sb.toString();
  }

  bool _parseBoolean() {
    final start = _peek();
    if (start == 't') {
      if (_input.substring(_pos, _pos + 4) == 'true') {
        _pos += 4;
        _col += 4;
        return true;
      }
    } else if (start == 'f') {
      if (_input.substring(_pos, _pos + 5) == 'false') {
        _pos += 5;
        _col += 5;
        return false;
      }
    }
    throw _error('Invalid boolean value');
  }

  bool _isNameStart(String c) => RegExp(r'^[a-zA-Z_\$]$').hasMatch(c);

  bool _isNamePart(String c) => RegExp(r'^[a-zA-Z0-9_\$\.\-]$').hasMatch(c);

  bool _isDigit(String c) => RegExp(r'^[0-9]$').hasMatch(c);

  int _parseInt() {
    final sb = StringBuffer();
    if (_peek() == '-') sb.write(_advance());
    while (_isDigit(_peek())) {
      sb.write(_advance());
    }
    final str = sb.toString();
    return int.parse(str);
  }

  double _parseDouble() {
    final sb = StringBuffer();
    if (_peek() == '-') sb.write(_advance());
    bool hasDot = false;
    while (_isDigit(_peek()) || (!hasDot && _peek() == '.')) {
      if (_peek() == '.') hasDot = true;
      sb.write(_advance());
    }
    final str = sb.toString();
    return double.parse(str);
  }

  Exception _error(String msg) =>
      FormatException('TSON parse error at line $_line, col $_col: $msg');
}
