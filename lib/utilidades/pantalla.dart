// lib/utilidades/pantalla.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Extensiones útiles traducidas a español.
/// Uso:
///   context.anchoPct(0.6) -> 60% del ancho
///   context.altoPct(0.2) -> 20% de la altura
///   context.minimoPct(0.1) -> 10% de la dimensión mínima (w/h)
///   context.tamTexto(16) -> tamaño de texto escalado según devicePixelRatio/textScaleFactor
extension TamanoPantallaExtension on BuildContext {
  double anchoPct(double percent) {
    assert(percent >= 0 && percent <= 1, 'percent debe estar entre 0 y 1');
    return MediaQuery.of(this).size.width * percent;
  }

  double altoPct(double percent) {
    assert(percent >= 0 && percent <= 1, 'percent debe estar entre 0 y 1');
    return MediaQuery.of(this).size.height * percent;
  }

  double minimoPct(double percent) {
    assert(percent >= 0 && percent <= 1, 'percent debe estar entre 0 y 1');
    final s = MediaQuery.of(this).size;
    return math.min(s.width, s.height) * percent;
  }

  double tamTexto(double base) {
    final mq = MediaQuery.of(this);
    // `textScaleFactor` está deprecado en algunas versiones; ignoramos la
    // advertencia temporalmente hasta que se actualice la estrategia global.
    // ignore: deprecated_member_use
    final scale = mq.textScaleFactor * (mq.devicePixelRatio / 2.0);
    return base * scale;
  }
}
