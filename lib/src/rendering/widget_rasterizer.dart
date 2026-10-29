import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/raster.dart';
import 'bitmap_converter.dart';

/// Renders arbitrary Flutter widget trees into monochrome bitmaps for thermal printing.
class WidgetRasterizer {
  WidgetRasterizer._();

  /// Captures [widget] at [widthDots] and converts it into a ready-to-print [MonoBitmap].
  static Future<MonoBitmap> rasterizeWidget(
    Widget widget, {
    required int widthDots,
    int threshold = 128,
    bool dither = false,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();

    final view = ui.PlatformDispatcher.instance.views.first;
    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(
        alignment: Alignment.topLeft,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tightFor(width: widthDots.toDouble()),
        devicePixelRatio: 1.0,
      ),
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData.fromView(view),
          child: Material(
            color: Colors.white,
            child: widget,
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner
      ..buildScope(rootElement)
      ..finalizeTree();

    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      throw StateError('Failed to capture widget image pixels');
    }

    final pixels = Uint8List(image.width * image.height);
    final bytes = byteData.buffer.asUint8List();

    for (var i = 0, p = 0; i < bytes.length; i += 4, p++) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final a = bytes[i + 3];

      if (a < 128) {
        pixels[p] = 255;
      } else {
        pixels[p] = ((299 * r + 587 * g + 114 * b) ~/ 1000).clamp(0, 255);
      }
    }

    final gray = GrayBitmap(
      width: image.width,
      height: image.height,
      pixels: pixels,
    );

    return BitmapConverter.toMonoAsync(
      gray,
      threshold: threshold,
      dither: dither,
    );
  }
}
