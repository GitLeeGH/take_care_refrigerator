import 'package:flutter/material.dart';

enum IngredientArt {
  sprouts,
  mushrooms,
  chips,
  sausage,
  egg,
  tofu,
  softTofu,
  cabbage,
  redCabbage,
  redOnion,
  bellPepper,
  yellowPepper,
  greenPepper,
  scallion,
  carrot,
  garlic,
  mincedGarlic,
  leafy,
  salt,
  pepper,
  oil,
  sesameOil,
  perillaOil,
  onion,
  potato,
  sweetPotato,
  eggplant,
  zucchini,
  tomato,
  cucumber,
  chili,
  broccoli,
  cauliflower,
  apple,
  fish,
  meat,
  milk,
  grain,
  grocery,
}

/// Visual matching only. Never use this to infer storage or dates.
IngredientArt ingredientArtFor(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final produce = n.replaceAll(
    RegExp(r'\(?\d+(?:\.\d+)?(?:kg|g|ml|l|개|봉|팩|통|병)\)?$'),
    '',
  );
  if (const ['가지', 'eggplant', 'aubergine'].contains(produce)) {
    return IngredientArt.eggplant;
  }
  if (const ['후춧가루', '후추가루', '분쇄후추'].contains(produce)) {
    return IngredientArt.pepper;
  }
  if (RegExp(
    '소스|분말|가루|케이크|과자|주스|쥬스|스프|수프|잼|장아찌|김치|볶음|조림|튀김|찌개|빵|두부면|포두부|건두부|두부피|sauce|powder|cake|juice|bread|cookie',
  ).hasMatch(n)) {
    return IngredientArt.grocery;
  }
  if (const ['적양배추', '자색양배추', 'redcabbage'].contains(produce)) {
    return IngredientArt.redCabbage;
  }
  if (const ['다진마늘', '간마늘'].contains(produce)) {
    return IngredientArt.mincedGarlic;
  }
  if (const ['순두부', '연두부', 'silkentofu'].contains(produce)) {
    return IngredientArt.softTofu;
  }
  if (const ['양배추', 'cabbage'].contains(produce)) return IngredientArt.cabbage;
  if (const ['대파', '쪽파', '실파', 'scallion', 'greenonion'].contains(produce)) {
    return IngredientArt.scallion;
  }
  if (const ['새송이', '느타리', '표고', '팽이', '양송이', '만가닥'].contains(produce)) {
    return IngredientArt.mushrooms;
  }
  if (RegExp('감자칩|포테이토칩|potatochips').hasMatch(n)) return IngredientArt.chips;
  if (RegExp('소시지|소세지|부어스트|프랑크|sausage').hasMatch(n)) {
    return IngredientArt.sausage;
  }
  if (RegExp('숙주|콩나물|beansprout').hasMatch(n)) return IngredientArt.sprouts;
  if (RegExp('버섯|mushroom').hasMatch(n)) return IngredientArt.mushrooms;
  if (RegExp('달걀|계란').hasMatch(n) || const ['egg', 'eggs'].contains(produce)) {
    return IngredientArt.egg;
  }
  if (RegExp('두부|tofu').hasMatch(n)) return IngredientArt.tofu;
  const exactArt = <String, IngredientArt>{
    '소금': IngredientArt.salt,
    '천일염': IngredientArt.salt,
    '꽃소금': IngredientArt.salt,
    '굵은소금': IngredientArt.salt,
    '맛소금': IngredientArt.salt,
    'salt': IngredientArt.salt,
    '후추': IngredientArt.pepper,
    '통후추': IngredientArt.pepper,
    '백후추': IngredientArt.pepper,
    'blackpepper': IngredientArt.pepper,
    '식용유': IngredientArt.oil,
    '올리브유': IngredientArt.oil,
    '올리브오일': IngredientArt.oil,
    '콩기름': IngredientArt.oil,
    '카놀라유': IngredientArt.oil,
    '포도씨유': IngredientArt.oil,
    '해바라기유': IngredientArt.oil,
    '옥수수유': IngredientArt.oil,
    '아보카도유': IngredientArt.oil,
    'cookingoil': IngredientArt.oil,
    '참기름': IngredientArt.sesameOil,
    '들기름': IngredientArt.perillaOil,
    'perillaoil': IngredientArt.perillaOil,
    'sesameoil': IngredientArt.sesameOil,
    '양파': IngredientArt.onion,
    '적양파': IngredientArt.redOnion,
    '자색양파': IngredientArt.redOnion,
    'redonion': IngredientArt.redOnion,
    '파프리카': IngredientArt.bellPepper,
    '빨강파프리카': IngredientArt.bellPepper,
    '빨간파프리카': IngredientArt.bellPepper,
    '홍파프리카': IngredientArt.bellPepper,
    'redbellpepper': IngredientArt.bellPepper,
    '노랑파프리카': IngredientArt.yellowPepper,
    '노란파프리카': IngredientArt.yellowPepper,
    'yellowbellpepper': IngredientArt.yellowPepper,
    '피망': IngredientArt.greenPepper,
    '청피망': IngredientArt.greenPepper,
    '초록파프리카': IngredientArt.greenPepper,
    'greenbellpepper': IngredientArt.greenPepper,
    '홍피망': IngredientArt.bellPepper,
    '감자': IngredientArt.potato,
    '고구마': IngredientArt.sweetPotato,
    '밤고구마': IngredientArt.sweetPotato,
    '호박고구마': IngredientArt.sweetPotato,
    'sweetpotato': IngredientArt.sweetPotato,
    '토마토': IngredientArt.tomato,
    '방울토마토': IngredientArt.tomato,
    '오이': IngredientArt.cucumber,
    'zucchini': IngredientArt.zucchini,
    '주키니': IngredientArt.zucchini,
    '주키니호박': IngredientArt.zucchini,
    '애호박': IngredientArt.zucchini,
    '고추': IngredientArt.chili,
    '청양고추': IngredientArt.chili,
    '풋고추': IngredientArt.chili,
    '홍고추': IngredientArt.chili,
    '꽈리고추': IngredientArt.chili,
    '브로콜리': IngredientArt.broccoli,
    '콜리플라워': IngredientArt.cauliflower,
    '컬리플라워': IngredientArt.cauliflower,
    '사과': IngredientArt.apple,
    '생선': IngredientArt.fish,
    '고등어': IngredientArt.fish,
    '갈치': IngredientArt.fish,
    '대구': IngredientArt.fish,
    '명태': IngredientArt.fish,
    '동태': IngredientArt.fish,
    '가자미': IngredientArt.fish,
    '광어': IngredientArt.fish,
    '참치': IngredientArt.fish,
    '꽁치': IngredientArt.fish,
    '연어': IngredientArt.fish,
    '소고기': IngredientArt.meat,
    '쇠고기': IngredientArt.meat,
    '돼지고기': IngredientArt.meat,
    '양고기': IngredientArt.meat,
    '삼겹살': IngredientArt.meat,
    '목살': IngredientArt.meat,
    '앞다리살': IngredientArt.meat,
    '안심': IngredientArt.meat,
    '등심': IngredientArt.meat,
    '우유': IngredientArt.milk,
    '두유': IngredientArt.milk,
    '아몬드우유': IngredientArt.milk,
    '귀리우유': IngredientArt.milk,
    '쌀': IngredientArt.grain,
    '현미': IngredientArt.grain,
    '찹쌀': IngredientArt.grain,
    '흑미': IngredientArt.grain,
    '귀리': IngredientArt.grain,
    '보리': IngredientArt.grain,
    '퀴노아': IngredientArt.grain,
    '수수': IngredientArt.grain,
    '기장': IngredientArt.grain,
    '조': IngredientArt.grain,
    '콩': IngredientArt.grain,
    '검은콩': IngredientArt.grain,
    '병아리콩': IngredientArt.grain,
    '강낭콩': IngredientArt.grain,
    '렌틸콩': IngredientArt.grain,
    '녹두': IngredientArt.grain,
    '팥': IngredientArt.grain,
  };
  if (exactArt.containsKey(produce)) return exactArt[produce]!;
  if (RegExp(r'^(마늘|통마늘|깐마늘|garlic)$').hasMatch(produce)) {
    return IngredientArt.garlic;
  }
  if (RegExp('당근|carrot').hasMatch(n)) return IngredientArt.carrot;
  if (RegExp('상추|배추|시금치|청경채|케일').hasMatch(n)) return IngredientArt.leafy;
  return IngredientArt.grocery;
}

/// Original app-drawn vector art. Uploaded photographs keep priority.
class IngredientIllustration extends StatelessWidget {
  const IngredientIllustration({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name 재료 일러스트',
    child: SizedBox(
      width: 76,
      height: 52,
      child: CustomPaint(painter: _IngredientPainter(ingredientArtFor(name))),
    ),
  );
}

class _IngredientPainter extends CustomPainter {
  const _IngredientPainter(this.kind);
  final IngredientArt kind;
  static const ink = Color(0xFF65543E),
      cream = Color(0xFFFFF6DC),
      green = Color(0xFF759666);
  void shape(Canvas c, Path p, Color color) {
    c.drawPath(p, Paint()..color = color);
    c.drawPath(
      p,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void oval(Canvas c, Rect r, Color color) =>
      shape(c, Path()..addOval(r), color);
  void box(Canvas c, Rect r, Color color, [double radius = 5]) => shape(
    c,
    Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))),
    color,
  );
  void line(Canvas c, Path p, Color color, [double width = 2]) => c.drawPath(
    p,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  @override
  void paint(Canvas c, Size size) {
    c.save();
    final scale = size.width / 100 < size.height / 72
        ? size.width / 100
        : size.height / 72;
    c.translate((size.width - 100 * scale) / 2, (size.height - 72 * scale) / 2);
    c.scale(scale);
    c.drawOval(
      const Rect.fromLTWH(14, 59, 72, 8),
      Paint()..color = const Color(0x19596849),
    );
    switch (kind) {
      case IngredientArt.sprouts:
        for (var i = 0; i < 7; i++) {
          final x = 22.0 + i * 8, y = 15.0 + (i % 3) * 5;
          final p = Path()
            ..moveTo(x, y + 6)
            ..cubicTo(x - 11, 35, x + 13, 43, x - 3, 57)
            ..quadraticBezierTo(x - 8, 61, x - 2, 63);
          line(c, p, const Color(0xFFB9A681), 5);
          line(c, p, cream, 3.4);
          oval(
            c,
            Rect.fromCenter(center: Offset(x, y), width: 11, height: 8),
            const Color(0xFFDCC36C),
          );
          if (i.isEven) oval(c, Rect.fromLTWH(x + 3, y - 6, 8, 5), green);
        }
      case IngredientArt.mushrooms:
        for (final p in [
          const Offset(30, 29),
          const Offset(70, 32),
          const Offset(50, 16),
        ]) {
          box(c, Rect.fromLTWH(p.dx - 5, p.dy + 8, 10, 35), cream, 4);
          shape(
            c,
            Path()
              ..moveTo(p.dx - 19, p.dy + 12)
              ..cubicTo(
                p.dx - 17,
                p.dy - 12,
                p.dx + 17,
                p.dy - 12,
                p.dx + 19,
                p.dy + 12,
              )
              ..quadraticBezierTo(p.dx, p.dy + 20, p.dx - 19, p.dy + 12)
              ..close(),
            const Color(0xFFB79572),
          );
          line(
            c,
            Path()
              ..moveTo(p.dx - 11, p.dy + 12)
              ..quadraticBezierTo(p.dx, p.dy + 16, p.dx + 11, p.dy + 12),
            const Color(0xFF84664D),
            1.3,
          );
        }
      case IngredientArt.chips:
        shape(
          c,
          Path()
            ..moveTo(20, 8)
            ..lineTo(65, 8)
            ..lineTo(68, 60)
            ..lineTo(18, 60)
            ..close(),
          const Color(0xFFE6BD6B),
        );
        box(c, const Rect.fromLTWH(21, 11, 43, 6), green, 1);
        box(c, const Rect.fromLTWH(21, 51, 43, 6), green, 1);
        oval(c, const Rect.fromLTWH(27, 24, 29, 20), cream);
        for (var i = 0; i < 3; i++) {
          final x = 62.0 + i * 6, y = 37.0 + i * 7;
          oval(c, Rect.fromLTWH(x, y, 19, 13), const Color(0xFFF1D58C));
          line(
            c,
            Path()
              ..moveTo(x + 6, y + 3)
              ..lineTo(x + 4, y + 9)
              ..moveTo(x + 12, y + 3)
              ..lineTo(x + 10, y + 10),
            const Color(0xFFBE9B58),
            1,
          );
        }
      case IngredientArt.sausage:
        for (var i = 0; i < 3; i++) {
          c.save();
          c.translate(22.0 + i * 17, 13.0 + i * 3);
          c.rotate(-0.35);
          box(c, const Rect.fromLTWH(0, 0, 17, 44), const Color(0xFFC78663), 8);
          for (var j = 0; j < 3; j++) {
            line(
              c,
              Path()
                ..moveTo(5, 10.0 + j * 10)
                ..lineTo(12, 7.0 + j * 10),
              const Color(0xFF8F563E),
            );
          }
          c.restore();
        }
      case IngredientArt.egg:
        oval(c, const Rect.fromLTWH(18, 13, 33, 47), const Color(0xFFDEC49E));
        oval(c, const Rect.fromLTWH(48, 23, 38, 35), cream);
        oval(c, const Rect.fromLTWH(58, 30, 19, 20), const Color(0xFFE6B84B));
      case IngredientArt.softTofu:
        oval(c, const Rect.fromLTWH(17, 28, 67, 28), const Color(0xFFE5ECE2));
        shape(
          c,
          Path()
            ..moveTo(17, 40)
            ..quadraticBezierTo(22, 65, 50, 64)
            ..quadraticBezierTo(78, 65, 84, 40)
            ..quadraticBezierTo(50, 56, 17, 40)
            ..close(),
          const Color(0xFF8EAFA2),
        );
        shape(
          c,
          Path()
            ..moveTo(26, 36)
            ..quadraticBezierTo(25, 24, 37, 25)
            ..quadraticBezierTo(42, 16, 54, 24)
            ..quadraticBezierTo(70, 19, 74, 35)
            ..quadraticBezierTo(69, 47, 49, 46)
            ..quadraticBezierTo(30, 48, 26, 36)
            ..close(),
          const Color(0xFFFFF1D7),
        );
        line(
          c,
          Path()
            ..moveTo(37, 29)
            ..quadraticBezierTo(44, 35, 49, 29)
            ..quadraticBezierTo(55, 24, 62, 30),
          const Color(0xFFE3D2B4),
          1.8,
        );
      case IngredientArt.cabbage:
      case IngredientArt.redCabbage:
        oval(
          c,
          const Rect.fromLTWH(22, 13, 57, 49),
          kind == IngredientArt.redCabbage
              ? const Color(0xFFAE7AAB)
              : const Color(0xFFA3BE83),
        );
        shape(
          c,
          Path()
            ..moveTo(50, 61)
            ..cubicTo(18, 66, 10, 39, 24, 31)
            ..quadraticBezierTo(36, 31, 50, 61)
            ..close(),
          kind == IngredientArt.redCabbage
              ? const Color(0xFF80577F)
              : const Color(0xFF729968),
        );
        shape(
          c,
          Path()
            ..moveTo(49, 61)
            ..cubicTo(84, 63, 91, 38, 76, 29)
            ..quadraticBezierTo(61, 34, 49, 61)
            ..close(),
          kind == IngredientArt.redCabbage
              ? const Color(0xFF996591)
              : const Color(0xFF85A973),
        );
        line(
          c,
          Path()
            ..moveTo(50, 58)
            ..quadraticBezierTo(34, 44, 26, 35),
          kind == IngredientArt.redCabbage
              ? const Color(0xFFE9CDE1)
              : const Color(0xFFDCE5BD),
          2,
        );
        line(
          c,
          Path()
            ..moveTo(51, 57)
            ..quadraticBezierTo(66, 41, 76, 34),
          kind == IngredientArt.redCabbage
              ? const Color(0xFFE9CDE1)
              : const Color(0xFFDCE5BD),
          2,
        );
        line(
          c,
          Path()
            ..moveTo(40, 22)
            ..quadraticBezierTo(54, 14, 65, 29)
            ..quadraticBezierTo(69, 38, 59, 43),
          kind == IngredientArt.redCabbage
              ? const Color(0xFFE9CDE1)
              : const Color(0xFFDCE5BD),
          2,
        );
        line(
          c,
          Path()
            ..moveTo(33, 28)
            ..quadraticBezierTo(49, 24, 53, 40),
          kind == IngredientArt.redCabbage
              ? const Color(0xFFE9CDE1)
              : const Color(0xFFDCE5BD),
          2,
        );
      case IngredientArt.scallion:
        for (var i = 0; i < 3; i++) {
          final x = 23.0 + i * 17;
          line(
            c,
            Path()
              ..moveTo(x, 54)
              ..lineTo(x + 5, 37),
            const Color(0xFF9A9771),
            9,
          );
          line(
            c,
            Path()
              ..moveTo(x, 54)
              ..lineTo(x + 5, 37),
            cream,
            7,
          );
          line(
            c,
            Path()
              ..moveTo(x + 5, 38)
              ..quadraticBezierTo(x + 10, 21, x + 8, 10),
            const Color(0xFF54834F),
            7,
          );
          line(
            c,
            Path()
              ..moveTo(x + 8, 34)
              ..lineTo(x + 17, 13),
            const Color(0xFF81A766),
            4,
          );
          line(
            c,
            Path()
              ..moveTo(x, 54)
              ..lineTo(x - 4, 62)
              ..moveTo(x, 55)
              ..lineTo(x + 1, 64)
              ..moveTo(x + 1, 54)
              ..lineTo(x + 5, 61),
            const Color(0xFFBEA476),
            1.2,
          );
        }
      case IngredientArt.tofu:
        shape(
          c,
          Path()
            ..moveTo(18, 24)
            ..lineTo(65, 16)
            ..lineTo(84, 29)
            ..lineTo(84, 55)
            ..lineTo(36, 63)
            ..lineTo(18, 49)
            ..close(),
          const Color(0xFFE4D8B9),
        );
        shape(
          c,
          Path()
            ..moveTo(18, 24)
            ..lineTo(65, 16)
            ..lineTo(84, 29)
            ..lineTo(36, 37)
            ..close(),
          cream,
        );
        line(
          c,
          Path()
            ..moveTo(36, 37)
            ..lineTo(36, 63),
          ink,
          1.5,
        );
        for (final p in [
          const Offset(37, 25),
          const Offset(58, 23),
          const Offset(64, 30),
        ]) {
          c.drawCircle(p, 1.3, Paint()..color = const Color(0xFFC6B994));
        }
      case IngredientArt.carrot:
        // A tapered root, rounded shoulder and separate leafy crown.
        for (final angle in [-0.65, -0.2, 0.3, 0.75]) {
          c.save();
          c.translate(58, 25);
          c.rotate(angle);
          shape(
            c,
            Path()
              ..moveTo(0, 0)
              ..cubicTo(-9, -8, -7, -18, -2, -21)
              ..quadraticBezierTo(5, -19, 4, -12)
              ..quadraticBezierTo(10, -9, 0, 0)
              ..close(),
            green,
          );
          line(
            c,
            Path()
              ..moveTo(0, -2)
              ..lineTo(0, -15),
            const Color(0xFF456B42),
            1,
          );
          c.restore();
        }
        final root = Path()
          ..moveTo(48, 24)
          ..cubicTo(54, 19, 67, 25, 65, 33)
          ..cubicTo(60, 45, 38, 58, 26, 64)
          ..quadraticBezierTo(24, 65, 25, 62)
          ..cubicTo(29, 49, 38, 32, 48, 24)
          ..close();
        shape(c, root, const Color(0xFFE99B51));
        c.save();
        c.clipPath(root);
        c.drawPath(
          Path()
            ..moveTo(63, 25)
            ..cubicTo(61, 42, 38, 59, 25, 65)
            ..lineTo(72, 65)
            ..lineTo(74, 20)
            ..close(),
          Paint()..color = const Color(0xFFD98440),
        );
        line(
          c,
          Path()
            ..moveTo(48, 29)
            ..quadraticBezierTo(38, 40, 32, 52),
          const Color(0xFFF6BF77),
          3,
        );
        c.restore();
        for (final p in [
          const Offset(47, 33),
          const Offset(49, 43),
          const Offset(33, 51),
        ]) {
          line(
            c,
            Path()
              ..moveTo(p.dx, p.dy)
              ..lineTo(p.dx + 5, p.dy + 3),
            const Color(0xFFAD642F),
            1.4,
          );
        }
      case IngredientArt.mincedGarlic:
        oval(c, const Rect.fromLTWH(18, 32, 64, 24), const Color(0xFFE5ECE2));
        shape(
          c,
          Path()
            ..moveTo(18, 43)
            ..quadraticBezierTo(22, 65, 50, 64)
            ..quadraticBezierTo(77, 65, 82, 43)
            ..quadraticBezierTo(50, 56, 18, 43)
            ..close(),
          const Color(0xFF9FB9A5),
        );
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 5; col++) {
            final x = 27.0 + col * 9 + (row.isOdd ? 3 : 0);
            final y = 25.0 + row * 7 + (col.isOdd ? 2 : 0);
            box(
              c,
              Rect.fromLTWH(x, y, 9, 7),
              col.isEven ? cream : const Color(0xFFEAD7AC),
              2,
            );
          }
        }
      case IngredientArt.garlic:
        shape(
          c,
          Path()
            ..moveTo(44, 10)
            ..lineTo(54, 9)
            ..quadraticBezierTo(51, 23, 62, 28)
            ..cubicTo(88, 40, 76, 63, 52, 63)
            ..cubicTo(23, 66, 16, 44, 33, 31)
            ..quadraticBezierTo(45, 24, 44, 10)
            ..close(),
          const Color(0xFFF2E7D2),
        );
        shape(
          c,
          Path()
            ..moveTo(48, 26)
            ..cubicTo(34, 36, 29, 53, 44, 61)
            ..quadraticBezierTo(51, 65, 58, 60)
            ..cubicTo(70, 47, 57, 31, 48, 26)
            ..close(),
          const Color(0xFFFFF8E8),
        );
        line(
          c,
          Path()
            ..moveTo(48, 29)
            ..quadraticBezierTo(44, 44, 48, 59),
          const Color(0xFFD1BDA8),
          1.3,
        );
        line(
          c,
          Path()
            ..moveTo(57, 30)
            ..quadraticBezierTo(73, 43, 64, 57),
          const Color(0xFFD1BDA8),
          1.3,
        );
        for (var i = 0; i < 3; i++) {
          line(
            c,
            Path()
              ..moveTo(46.0 + i * 4, 62)
              ..lineTo(44.0 + i * 6, 66),
            ink,
            1,
          );
        }
        shape(
          c,
          Path()
            ..moveTo(78, 45)
            ..cubicTo(89, 49, 86, 63, 76, 64)
            ..cubicTo(66, 64, 65, 56, 72, 52)
            ..quadraticBezierTo(77, 50, 78, 45)
            ..close(),
          cream,
        );
        line(
          c,
          Path()
            ..moveTo(78, 51)
            ..quadraticBezierTo(80, 56, 76, 60),
          const Color(0xFFD1BDA8),
          1,
        );
      case IngredientArt.leafy:
        for (var i = 0; i < 5; i++) {
          c.save();
          c.translate(50, 59);
          c.rotate((i - 2) * 0.34);
          shape(
            c,
            Path()
              ..moveTo(0, 0)
              ..cubicTo(-25, -16, -19, -49, 0, -48)
              ..cubicTo(19, -49, 25, -16, 0, 0)
              ..close(),
            i.isEven ? green : const Color(0xFF91AF77),
          );
          line(
            c,
            Path()
              ..moveTo(0, -2)
              ..lineTo(0, -39)
              ..moveTo(0, -18)
              ..lineTo(-9, -26)
              ..moveTo(0, -27)
              ..lineTo(9, -34),
            cream,
            1.5,
          );
          c.restore();
        }
      case IngredientArt.salt:
      case IngredientArt.pepper:
        final dark = kind == IngredientArt.pepper;
        box(
          c,
          const Rect.fromLTWH(31, 21, 38, 42),
          dark ? const Color(0xFFC2A17D) : cream,
          10,
        );
        box(c, const Rect.fromLTWH(30, 11, 40, 16), const Color(0xFF99AD98), 5);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset(40.0 + i * 10, 17), 1.6, Paint()..color = ink);
        }
        for (var i = 0; i < 9; i++) {
          c.drawCircle(
            Offset(39.0 + (i % 3) * 10, 36.0 + (i ~/ 3) * 9),
            dark ? 2 : 1.3,
            Paint()..color = dark ? ink : const Color(0xFFC8B994),
          );
        }
      case IngredientArt.oil:
      case IngredientArt.sesameOil:
      case IngredientArt.perillaOil:
        box(c, const Rect.fromLTWH(42, 5, 16, 11), green, 3);
        shape(
          c,
          Path()
            ..moveTo(42, 16)
            ..lineTo(58, 16)
            ..lineTo(58, 23)
            ..quadraticBezierTo(68, 26, 68, 34)
            ..lineTo(68, 58)
            ..quadraticBezierTo(68, 64, 62, 64)
            ..lineTo(38, 64)
            ..quadraticBezierTo(32, 64, 32, 58)
            ..lineTo(32, 34)
            ..quadraticBezierTo(32, 26, 42, 23)
            ..close(),
          kind == IngredientArt.oil
              ? const Color(0xFFE7C65E)
              : const Color(0xFFB87938),
        );
        box(c, const Rect.fromLTWH(36, 36, 28, 18), cream, 3);
        line(
          c,
          Path()
            ..moveTo(39, 29)
            ..lineTo(39, 33),
          const Color(0xFFFFE5A1),
          3,
        );
        if (kind == IngredientArt.sesameOil) {
          for (var i = 0; i < 3; i++) {
            oval(
              c,
              Rect.fromLTWH(42.0 + i * 5, 42.0 + (i % 2) * 3, 5, 3),
              const Color(0xFFD9BC83),
            );
          }
        } else {
          oval(c, const Rect.fromLTWH(44, 40, 12, 8), green);
        }
      case IngredientArt.onion:
      case IngredientArt.redOnion:
        shape(
          c,
          Path()
            ..moveTo(47, 12)
            ..lineTo(55, 12)
            ..quadraticBezierTo(53, 24, 67, 33)
            ..cubicTo(90, 56, 67, 67, 48, 63)
            ..cubicTo(21, 68, 12, 45, 33, 31)
            ..quadraticBezierTo(46, 24, 47, 12)
            ..close(),
          kind == IngredientArt.redOnion
              ? const Color(0xFFAA6682)
              : const Color(0xFFD9AD70),
        );
        for (final x in [37.0, 48.0, 59.0]) {
          line(
            c,
            Path()
              ..moveTo(50, 25)
              ..quadraticBezierTo(x - 12, 42, x, 59),
            kind == IngredientArt.redOnion
                ? const Color(0xFFE4B2C9)
                : const Color(0xFFAA7E49),
            1.3,
          );
        }
        line(
          c,
          Path()
            ..moveTo(45, 63)
            ..lineTo(42, 67)
            ..moveTo(51, 63)
            ..lineTo(52, 67),
          ink,
          1,
        );
      case IngredientArt.eggplant:
        shape(
          c,
          Path()
            ..moveTo(67, 19)
            ..cubicTo(75, 30, 72, 43, 56, 56)
            ..cubicTo(40, 70, 20, 62, 22, 48)
            ..cubicTo(23, 36, 43, 31, 54, 21)
            ..close(),
          const Color(0xFF614568),
        );
        line(
          c,
          Path()
            ..moveTo(31, 48)
            ..quadraticBezierTo(39, 39, 54, 34),
          const Color(0xFFAA83AC),
          4,
        );
        shape(
          c,
          Path()
            ..moveTo(54, 21)
            ..lineTo(58, 12)
            ..lineTo(64, 15)
            ..lineTo(73, 16)
            ..lineTo(68, 23)
            ..lineTo(71, 30)
            ..lineTo(60, 26)
            ..lineTo(54, 31)
            ..close(),
          const Color(0xFF669061),
        );
        line(
          c,
          Path()
            ..moveTo(62, 16)
            ..quadraticBezierTo(64, 7, 72, 8),
          const Color(0xFF52764C),
          4,
        );
      case IngredientArt.sweetPotato:
        shape(
          c,
          Path()
            ..moveTo(18, 46)
            ..cubicTo(26, 23, 57, 18, 74, 26)
            ..cubicTo(86, 34, 69, 48, 42, 56)
            ..quadraticBezierTo(20, 65, 18, 46)
            ..close(),
          const Color(0xFF98566B),
        );
        line(
          c,
          Path()
            ..moveTo(28, 40)
            ..quadraticBezierTo(44, 28, 63, 30),
          const Color(0xFFC68B98),
          3,
        );
        for (final point in [
          const Offset(32, 46),
          const Offset(48, 38),
          const Offset(60, 42),
        ]) {
          line(
            c,
            Path()
              ..moveTo(point.dx, point.dy)
              ..lineTo(point.dx + 3, point.dy - 1),
            const Color(0xFF703D50),
            1.5,
          );
        }
        oval(c, const Rect.fromLTWH(56, 40, 27, 22), const Color(0xFF965166));
        oval(c, const Rect.fromLTWH(59, 42, 21, 17), const Color(0xFFF1D07A));
      case IngredientArt.zucchini:
        shape(
          c,
          Path()
            ..moveTo(23, 27)
            ..cubicTo(17, 29, 16, 39, 24, 44)
            ..lineTo(72, 59)
            ..cubicTo(86, 61, 90, 44, 79, 39)
            ..close(),
          const Color(0xFF9BAE62),
        );
        line(
          c,
          Path()
            ..moveTo(29, 31)
            ..lineTo(75, 45),
          const Color(0xFFC9D695),
          3,
        );
        line(
          c,
          Path()
            ..moveTo(29, 39)
            ..lineTo(69, 52),
          const Color(0xFF6D8749),
          2,
        );
        shape(
          c,
          Path()
            ..moveTo(23, 27)
            ..lineTo(18, 21)
            ..lineTo(12, 25)
            ..lineTo(18, 33)
            ..close(),
          const Color(0xFF5C7847),
        );
        oval(c, const Rect.fromLTWH(68, 42, 19, 19), const Color(0xFF78914C));
        oval(c, const Rect.fromLTWH(71, 45, 13, 13), const Color(0xFFE2E5B6));
      case IngredientArt.potato:
        oval(c, const Rect.fromLTWH(18, 24, 43, 34), const Color(0xFFC5A274));
        oval(c, const Rect.fromLTWH(48, 31, 34, 30), const Color(0xFFD8B98A));
        for (final p in [
          const Offset(30, 34),
          const Offset(43, 45),
          const Offset(28, 48),
          const Offset(63, 39),
          const Offset(71, 50),
        ]) {
          line(
            c,
            Path()
              ..moveTo(p.dx, p.dy)
              ..lineTo(p.dx + 2, p.dy + 1),
            ink,
            1.5,
          );
        }
      case IngredientArt.tomato:
      case IngredientArt.apple:
        shape(
          c,
          Path()
            ..moveTo(50, 25)
            ..cubicTo(20, 8, 15, 41, 26, 55)
            ..quadraticBezierTo(39, 68, 50, 61)
            ..quadraticBezierTo(66, 69, 77, 50)
            ..cubicTo(89, 24, 69, 16, 50, 25)
            ..close(),
          const Color(0xFFD77259),
        );
        line(
          c,
          Path()
            ..moveTo(31, 33)
            ..quadraticBezierTo(25, 43, 31, 49),
          const Color(0xFFF2AB83),
          3,
        );
        if (kind == IngredientArt.tomato) {
          shape(
            c,
            Path()
              ..moveTo(50, 16)
              ..lineTo(54, 25)
              ..lineTo(65, 21)
              ..lineTo(58, 30)
              ..lineTo(65, 35)
              ..lineTo(52, 32)
              ..lineTo(44, 37)
              ..lineTo(46, 28)
              ..lineTo(35, 25)
              ..lineTo(47, 24)
              ..close(),
            green,
          );
        } else {
          line(
            c,
            Path()
              ..moveTo(50, 25)
              ..quadraticBezierTo(49, 15, 55, 10),
            ink,
            3,
          );
          oval(c, const Rect.fromLTWH(55, 13, 16, 8), green);
        }
      case IngredientArt.cucumber:
        c.save();
        c.translate(50, 36);
        c.rotate(0.55);
        box(
          c,
          const Rect.fromLTWH(-13, -29, 26, 58),
          const Color(0xFF799B66),
          13,
        );
        line(
          c,
          Path()
            ..moveTo(-5, -19)
            ..quadraticBezierTo(-8, 0, -5, 20),
          const Color(0xFFB7CE8F),
          3,
        );
        for (var i = 0; i < 4; i++) {
          c.drawCircle(Offset(6, -17.0 + i * 11), 1.3, Paint()..color = ink);
        }
        c.restore();
      case IngredientArt.bellPepper:
      case IngredientArt.yellowPepper:
      case IngredientArt.greenPepper:
        final body = kind == IngredientArt.yellowPepper
            ? const Color(0xFFE5B94B)
            : kind == IngredientArt.greenPepper
            ? const Color(0xFF70965D)
            : const Color(0xFFD86E55);
        final light = kind == IngredientArt.yellowPepper
            ? const Color(0xFFFFDC82)
            : kind == IngredientArt.greenPepper
            ? const Color(0xFFAACB88)
            : const Color(0xFFF4A78B);
        shape(
          c,
          Path()
            ..moveTo(49, 23)
            ..cubicTo(30, 10, 18, 24, 22, 41)
            ..cubicTo(24, 57, 30, 66, 41, 60)
            ..quadraticBezierTo(50, 68, 60, 60)
            ..cubicTo(73, 66, 81, 48, 79, 32)
            ..cubicTo(78, 19, 63, 16, 55, 23)
            ..close(),
          body,
        );
        line(
          c,
          Path()
            ..moveTo(37, 29)
            ..cubicTo(31, 37, 34, 49, 38, 54),
          light,
          4,
        );
        line(
          c,
          Path()
            ..moveTo(52, 31)
            ..quadraticBezierTo(57, 44, 53, 58),
          light,
          2,
        );
        shape(
          c,
          Path()
            ..moveTo(37, 23)
            ..lineTo(47, 20)
            ..lineTo(55, 19)
            ..lineTo(65, 25)
            ..lineTo(55, 27)
            ..lineTo(49, 31)
            ..lineTo(45, 26)
            ..close(),
          green,
        );
        line(
          c,
          Path()
            ..moveTo(50, 23)
            ..quadraticBezierTo(47, 12, 57, 9),
          const Color(0xFF4D7547),
          5,
        );
      case IngredientArt.chili:
        shape(
          c,
          Path()
            ..moveTo(54, 22)
            ..cubicTo(82, 24, 68, 56, 25, 62)
            ..quadraticBezierTo(48, 48, 44, 31)
            ..close(),
          const Color(0xFFCB6950),
        );
        shape(
          c,
          Path()
            ..moveTo(44, 28)
            ..lineTo(49, 19)
            ..lineTo(62, 23)
            ..lineTo(59, 32)
            ..close(),
          green,
        );
        line(
          c,
          Path()
            ..moveTo(53, 22)
            ..quadraticBezierTo(51, 12, 62, 9),
          green,
          4,
        );
      case IngredientArt.broccoli:
      case IngredientArt.cauliflower:
        shape(
          c,
          Path()
            ..moveTo(43, 35)
            ..lineTo(59, 35)
            ..lineTo(64, 63)
            ..lineTo(38, 63)
            ..close(),
          const Color(0xFFA6BA7C),
        );
        for (final p in [
          const Offset(31, 29),
          const Offset(49, 20),
          const Offset(69, 29),
          const Offset(49, 35),
        ]) {
          oval(
            c,
            Rect.fromCenter(center: p, width: 30, height: 27),
            kind == IngredientArt.cauliflower ? cream : green,
          );
        }
        line(
          c,
          Path()
            ..moveTo(49, 46)
            ..lineTo(49, 59),
          cream,
          2,
        );
      case IngredientArt.fish:
        shape(
          c,
          Path()
            ..moveTo(25, 40)
            ..lineTo(11, 26)
            ..lineTo(11, 54)
            ..close(),
          const Color(0xFF8EA7A0),
        );
        shape(
          c,
          Path()
            ..moveTo(22, 40)
            ..cubicTo(42, 10, 73, 16, 86, 40)
            ..cubicTo(70, 62, 42, 69, 22, 40)
            ..close(),
          const Color(0xFFB0C4B6),
        );
        line(
          c,
          Path()
            ..moveTo(66, 25)
            ..quadraticBezierTo(57, 40, 66, 55),
          ink,
          1.5,
        );
        c.drawCircle(const Offset(73, 36), 2, Paint()..color = ink);
        line(
          c,
          Path()
            ..moveTo(47, 35)
            ..lineTo(38, 45)
            ..lineTo(53, 44),
          green,
          2,
        );
      case IngredientArt.meat:
        shape(
          c,
          Path()
            ..moveTo(23, 28)
            ..cubicTo(45, 10, 80, 20, 80, 42)
            ..cubicTo(85, 67, 56, 66, 42, 57)
            ..cubicTo(18, 65, 12, 43, 23, 28)
            ..close(),
          const Color(0xFFC98E80),
        );
        line(
          c,
          Path()
            ..moveTo(28, 31)
            ..cubicTo(40, 26, 54, 29, 59, 43)
            ..quadraticBezierTo(65, 56, 74, 47),
          cream,
          4,
        );
        oval(c, const Rect.fromLTWH(31, 36, 14, 11), cream);
      case IngredientArt.milk:
        shape(
          c,
          Path()
            ..moveTo(31, 22)
            ..lineTo(41, 10)
            ..lineTo(64, 10)
            ..lineTo(72, 23)
            ..lineTo(72, 63)
            ..lineTo(31, 63)
            ..close(),
          cream,
        );
        shape(
          c,
          Path()
            ..moveTo(31, 22)
            ..lineTo(61, 22)
            ..lineTo(72, 23)
            ..lineTo(72, 63)
            ..lineTo(61, 63)
            ..lineTo(61, 22)
            ..close(),
          const Color(0xFFB0C4B6),
        );
        box(c, const Rect.fromLTWH(35, 35, 22, 17), green, 3);
        oval(c, const Rect.fromLTWH(42, 39, 8, 9), cream);
      case IngredientArt.grain:
        oval(c, const Rect.fromLTWH(22, 26, 57, 23), cream);
        for (var i = 0; i < 9; i++) {
          oval(
            c,
            Rect.fromLTWH(30.0 + (i % 3) * 14, 28.0 + (i ~/ 3) * 5, 9, 4),
            const Color(0xFFD7BC83),
          );
        }
        shape(
          c,
          Path()
            ..moveTo(22, 39)
            ..quadraticBezierTo(50, 53, 79, 39)
            ..quadraticBezierTo(74, 65, 50, 65)
            ..quadraticBezierTo(27, 65, 22, 39)
            ..close(),
          const Color(0xFF95AC8C),
        );
      case IngredientArt.grocery:
        box(c, const Rect.fromLTWH(24, 24, 52, 39), const Color(0xFFD6C8A7), 4);
        line(
          c,
          Path()
            ..moveTo(36, 27)
            ..lineTo(36, 18)
            ..cubicTo(36, 4, 64, 4, 64, 18)
            ..lineTo(64, 27),
          ink,
          3,
        );
        oval(c, const Rect.fromLTWH(42, 37, 16, 13), green);
        line(
          c,
          Path()
            ..moveTo(50, 51)
            ..lineTo(50, 43),
          cream,
          1.5,
        );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_IngredientPainter oldDelegate) =>
      kind != oldDelegate.kind;
}
