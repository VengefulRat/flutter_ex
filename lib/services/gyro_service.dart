import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Shared accelerometer → tilt provider.
/// All HoloCardV2 widgets call acquire() in initState and release() in
/// dispose. The underlying sensor stream only runs while refCount > 0.
class GyroService {
  GyroService._();
  static final instance = GyroService._();

  /// -1..1 in each axis. (0,0) means phone is upright and still.
  final ValueNotifier<Offset> tilt = ValueNotifier(Offset.zero);

  StreamSubscription<AccelerometerEvent>? _sub;
  int _refCount = 0;

  void acquire() {
    _refCount++;
    if (_refCount == 1) _start();
  }

  void release() {
    _refCount--;
    if (_refCount <= 0) {
      _refCount = 0;
      _stop();
    }
  }

  void _start() {
    try {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onEvent, onError: (e) {
        debugPrint('[GyroService] sensor error: $e');
      });
    } catch (e) {
      debugPrint('[GyroService] start failed: $e');
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    tilt.value = Offset.zero;
  }

  void _onEvent(AccelerometerEvent e) {
    // Portrait upright: y ≈ 9.81 (gravity up). x and z ≈ 0.
    // Tilt right  → x > 0. Tilt forward (top away) → z > 0, y < 9.81.
    final roll = atan2(e.x, e.y);
    final pitch = atan2(e.z, e.y);

    // Normalise to -1..1. The 0.45 divisor gives good sensitivity so a
    // modest wrist tilt produces a visible card response.
    final nx = (roll / 0.45).clamp(-1.0, 1.0);
    final ny = (pitch / 0.45).clamp(-1.0, 1.0);

    // Low-pass filter: accelerometer is noisy. Only push a new value when
    // it has meaningfully changed, which also saves rebuilds.
    final prev = tilt.value;
    final sx = prev.dx + (nx - prev.dx) * 0.18;
    final sy = prev.dy + (ny - prev.dy) * 0.18;
    if ((sx - prev.dx).abs() > 0.001 || (sy - prev.dy).abs() > 0.001) {
      tilt.value = Offset(sx, sy);
    }
  }
}