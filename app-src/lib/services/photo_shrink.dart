// Shrinks a picture so it stays small when it is kept with a payment (the longest side is at most [maxSide] pixels).

import 'dart:typed_data';
import 'dart:ui' as ui;

Future<Uint8List> shrinkPhoto(Uint8List bytes, {int maxSide = 1000}) async {
  try {
    final probe = await ui.instantiateImageCodec(bytes);
    final f = await probe.getNextFrame();
    final w = f.image.width, h = f.image.height;
    f.image.dispose();
    probe.dispose();
    if (w <= maxSide && h <= maxSide && bytes.length < 900 * 1024) return bytes;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: w >= h ? maxSide : null,
      targetHeight: h > w ? maxSide : null,
    );
    final fr = await codec.getNextFrame();
    final data = await fr.image.toByteData(format: ui.ImageByteFormat.png);
    fr.image.dispose();
    codec.dispose();
    return data == null ? bytes : data.buffer.asUint8List();
  } catch (_) {
    return bytes;
  }
}
