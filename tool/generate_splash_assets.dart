import 'dart:io';

import 'package:image/image.dart' as img;

/// Prepares the current logo for the native splash generators. Run from the
/// project root before `dart run flutter_native_splash:create`.
void main() {
  final source =
      img.decodePng(File('assets/icon/app_icon.png').readAsBytesSync());
  if (source == null) {
    throw StateError('Could not decode the Splitwize app icon.');
  }

  final output = Directory('assets/splash')..createSync(recursive: true);
  final splash = img.copyResize(source,
      width: 768, height: 768, interpolation: img.Interpolation.cubic);
  File('${output.path}/splash_icon.png')
      .writeAsBytesSync(img.encodePng(splash));

  // Android 12 uses a 1152px canvas masked to a 768px-diameter circle.
  // A 512px square (including its corners) fits inside that safe circle.
  final android12 = img.Image(width: 1152, height: 1152, numChannels: 4);
  img.fill(android12, color: img.ColorRgba8(0, 0, 0, 0));
  final logo = img.copyResize(source,
      width: 512, height: 512, interpolation: img.Interpolation.cubic);
  img.compositeImage(android12, logo, dstX: 320, dstY: 320);
  File('${output.path}/splash_android12.png')
      .writeAsBytesSync(img.encodePng(android12));
  stdout
      .writeln('Prepared native splash artwork from assets/icon/app_icon.png');
}
