import 'dart:io';

import 'package:image/image.dart' as img;

/// Prepares the shared app icon for native launcher and splash generators.
/// Run from the project root before generating launcher icons or splash screens.
void main() {
  final source =
      img.decodePng(File('assets/icon/app_icon.png').readAsBytesSync());
  if (source == null) {
    throw StateError('Could not decode the Splitwize app icon.');
  }

  // Legacy Android launchers need an opaque image; adaptive launchers and
  // splash screens keep the original transparency over the same green.
  final launcher = img.Image(width: source.width, height: source.height);
  img.fill(launcher, color: img.ColorRgb8(1, 58, 39));
  img.compositeImage(launcher, source);
  File('assets/icon/launcher_icon.png')
      .writeAsBytesSync(img.encodePng(launcher));

  final output = Directory('assets/splash')..createSync(recursive: true);
  final splash = img.copyResize(source,
      width: 768, height: 768, interpolation: img.Interpolation.cubic);
  File('${output.path}/splash_icon.png')
      .writeAsBytesSync(img.encodePng(splash));

  // Android 12 uses a 1152px canvas masked to a 768px-diameter circle.
  // The source already has transparent margins: at 1024px its visible artwork
  // fits inside that circle without adding another large layer of padding.
  final android12 = img.Image(width: 1152, height: 1152, numChannels: 4);
  img.fill(android12, color: img.ColorRgba8(0, 0, 0, 0));
  final logo = img.copyResize(source,
      width: 1024, height: 1024, interpolation: img.Interpolation.cubic);
  img.compositeImage(android12, logo, dstX: 64, dstY: 64);
  File('${output.path}/splash_android12.png')
      .writeAsBytesSync(img.encodePng(android12));
  stdout.writeln(
      'Prepared native launcher and splash artwork from assets/icon/app_icon.png');
}
