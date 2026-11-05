/// Chuỗi tiền Việt để hiển thị và đọc bằng TTS tiếng Việt.
abstract final class VndMoneyText {
  static const _digits = <String>[
    'không',
    'một',
    'hai',
    'ba',
    'bốn',
    'năm',
    'sáu',
    'bảy',
    'tám',
    'chín'
  ];
  static const _units = <String>[
    '',
    'nghìn',
    'triệu',
    'tỷ',
    'nghìn tỷ',
    'triệu tỷ'
  ];

  static String digits(int value) {
    final s = value.toString();
    final result = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return result.toString();
  }

  static String spoken(int value) {
    if (value < 0) throw ArgumentError.value(value, 'value');
    if (value == 0) return 'không đồng';
    var remaining = value;
    final groups = <int>[];
    while (remaining > 0) {
      groups.add(remaining % 1000);
      remaining ~/= 1000;
    }
    final words = <String>[];
    for (var i = groups.length - 1; i >= 0; i--) {
      final n = groups[i];
      if (n == 0) continue;
      final leading = i < groups.length - 1 && n < 100;
      words.add(_group(n, fullHundreds: leading));
      if (i > 0) words.add(_units[i]);
    }
    return '${words.join(' ')} đồng';
  }

  static String _group(int number, {required bool fullHundreds}) {
    final hundreds = number ~/ 100;
    final tens = (number % 100) ~/ 10;
    final units = number % 10;
    final words = <String>[];
    if (hundreds > 0) {
      words.add('${_digits[hundreds]} trăm');
    } else if (fullHundreds) {
      words.add('không trăm');
    }
    if (tens > 1) {
      words.add('${_digits[tens]} mươi');
      if (units == 1) {
        words.add('mốt');
      } else if (units == 4) {
        words.add('tư');
      } else if (units == 5) {
        words.add('lăm');
      } else if (units > 0) {
        words.add(_digits[units]);
      }
    } else if (tens == 1) {
      words.add('mười');
      if (units == 5) {
        words.add('lăm');
      } else if (units > 0) {
        words.add(_digits[units]);
      }
    } else if (units > 0) {
      if (hundreds > 0 || fullHundreds) words.add('linh');
      words.add(_digits[units]);
    }
    return words.join(' ');
  }
}
