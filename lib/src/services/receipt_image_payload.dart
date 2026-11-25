import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Coordinates are fractions of the orientation-corrected original image.
class ReceiptImageRegion {
  const ReceiptImageRegion(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
  bool get isValid =>
      [left, top, right, bottom].every((v) => v.isFinite && v >= 0 && v <= 1) &&
      right > left &&
      bottom > top;
}

class PreparedReceiptImage {
  PreparedReceiptImage(Uint8List bytes, this.width, this.height)
    : _bytes = Uint8List.fromList(bytes);
  final Uint8List _bytes;
  Uint8List get bytes => Uint8List.fromList(_bytes);
  final int width, height;
  String get sha256Hex => sha256.convert(_bytes).toString();
  String get mimeType => 'image/png';
}

const receiptImageConsentVersion = 'receipt-image-openai-owner-v2';

class ReviewedReceiptImage extends PreparedReceiptImage {
  ReviewedReceiptImage(PreparedReceiptImage image)
    : reviewedAt = DateTime.now().toUtc(),
      super(image.bytes, image.width, image.height);
  final DateTime reviewedAt;
  String get consentVersion => receiptImageConsentVersion;
}

class ReceiptImagePreparation {
  const ReceiptImagePreparation({
    required this.originalBytes,
    required this.crop,
    this.redactions = const [],
  });
  final Uint8List originalBytes;
  final ReceiptImageRegion crop;
  final List<ReceiptImageRegion> redactions;
}

/// Local only. A fresh RGB raster discards EXIF, GPS, comments and thumbnails.
/// Does not detect sensitive content; callers must obtain visual user review.
PreparedReceiptImage prepareReceiptImage(ReceiptImagePreparation request) {
  if (request.originalBytes.isEmpty ||
      request.originalBytes.length > 20 * 1024 * 1024 ||
      !request.crop.isValid ||
      request.redactions.any((r) => !r.isValid)) {
    throw const FormatException('사진 크기 또는 선택 영역을 확인해 주세요.');
  }
  final decoder = img.findDecoderForData(request.originalBytes);
  final info = decoder?.startDecode(request.originalBytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 24000000) {
    throw const FormatException('사진을 읽을 수 없거나 해상도가 너무 큽니다.');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('사진을 읽을 수 없습니다.');
  final oriented = img.bakeOrientation(decoded);
  final crop = request.crop;
  final x0 = (crop.left * oriented.width).ceil();
  final y0 = (crop.top * oriented.height).ceil();
  final x1 = (crop.right * oriented.width).floor();
  final y1 = (crop.bottom * oriented.height).floor();
  if (x1 <= x0 || y1 <= y0) throw const FormatException('품목 영역을 더 크게 선택해 주세요.');
  final clean = img.Image(width: x1 - x0, height: y1 - y0, numChannels: 3);
  for (var y = 0; y < clean.height; y++) {
    for (var x = 0; x < clean.width; x++) {
      final p = oriented.getPixel(x + x0, y + y0);
      final alpha = p.aNormalized;
      clean.setPixelRgb(
        x,
        y,
        (p.rNormalized * 255 * alpha + 255 * (1 - alpha)).round(),
        (p.gNormalized * 255 * alpha + 255 * (1 - alpha)).round(),
        (p.bNormalized * 255 * alpha + 255 * (1 - alpha)).round(),
      );
    }
  }
  for (final region in request.redactions) {
    final l = math.max(0, (region.left * oriented.width).floor() - x0);
    final t = math.max(0, (region.top * oriented.height).floor() - y0);
    final r = math.min(
      clean.width,
      (region.right * oriented.width).ceil() - x0,
    );
    final b = math.min(
      clean.height,
      (region.bottom * oriented.height).ceil() - y0,
    );
    for (var y = t; y < b; y++) {
      for (var x = l; x < r; x++) {
        clean.setPixelRgb(x, y, 0, 0, 0);
      }
    }
  }
  final edge = math.max(clean.width, clean.height);
  var output = edge > 1536
      ? img.copyResize(
          clean,
          width: math.max(1, (clean.width * 1536 / edge).round()),
          height: math.max(1, (clean.height * 1536 / edge).round()),
        )
      : clean;
  for (var attempt = 0; attempt < 4; attempt++) {
    final bytes = Uint8List.fromList(img.encodePng(output));
    if (bytes.length <= 2 * 1024 * 1024) {
      return PreparedReceiptImage(bytes, output.width, output.height);
    }
    output = img.copyResize(
      output,
      width: math.max(1, (output.width * .8).floor()),
      height: math.max(1, (output.height * .8).floor()),
    );
  }
  throw const FormatException('사진 용량이 너무 큽니다. 품목 영역을 줄여 주세요.');
}
