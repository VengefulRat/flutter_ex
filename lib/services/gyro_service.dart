import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Shared accelerometer → tilt provider.
///
/// Reports tilt RELATIVE to a baseline captured on start and on app
/// resume. This means the card sits flat in whatever position the
/// phone is held when the user opens the screen, and only responds
/// to changes from there.
class GyroService {
  GyroService._();
  static final instance = GyroService._();

  /// -1..1 in each axis, relative to baseline. (0,0) = phone is in
  /// whatever position was captured as neutral.
  final ValueNotifier<Offset> tilt = ValueNotifier(Offset.zero);

  StreamSubscription<AccelerometerEvent>? _sub;
  _LifecycleListener? _lifecycle;
  int _refCount = 0;

  Offset _raw = Offset.zero;
  Offset _baseline = Offset.zero;
  bool _baselineSet = false;

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

  /// Capture the current phone orientation as "neutral." Every card
  /// will appear flat at this position. Call this from any gesture
  /// if you want a manual recenter.
  void calibrate() {
    if (!_baselineSet) return;
    _baseline = _raw;
    tilt.value = Offset.zero;
  }

  void _start() {
    try {
      _lifecycle = _LifecycleListener(onResume: calibrate);
      WidgetsBinding.instance.addObserver(_lifecycle!);

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
    if (_lifecycle != null) {
      WidgetsBinding.instance.removeObserver(_lifecycle!);
      _lifecycle = null;
    }
    tilt.value = Offset.zero;
    _baselineSet = false;
    _raw = Offset.zero;
    _baseline = Offset.zero;
  }

  void _onEvent(AccelerometerEvent e) {
    final roll = atan2(e.x, e.y);
    final pitch = atan2(e.z, e.y);
    final nx = (roll / 0.45).clamp(-1.0, 1.0);
    final ny = (pitch / 0.45).clamp(-1.0, 1.0);

    // First event — seed the filter AND the baseline with the raw
    // reading. This is what makes the card start flat instead of
    // inheriting the phone's reading-angle tilt.
    if (!_baselineSet) {
      _raw = Offset(nx, ny);
      _baseline = _raw;
      _baselineSet = true;
      return;
    }

    _raw = Offset(
      _raw.dx + (nx - _raw.dx) * 0.18,
      _raw.dy + (ny - _raw.dy) * 0.18,
    );

    // Report tilt RELATIVE to baseline.
    final dx = (_raw.dx - _baseline.dx).clamp(-1.0, 1.0);
    final dy = (_raw.dy - _baseline.dy).clamp(-1.0, 1.0);

    final prev = tilt.value;
    if ((dx - prev.dx).abs() > 0.001 || (dy - prev.dy).abs() > 0.001) {
      tilt.value = Offset(dx, dy);
    }
  }
}

class _LifecycleListener with WidgetsBindingObserver {
  final VoidCallback onResume;
  _LifecycleListener({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Small delay so the accelerometer delivers fresh data after
      // resume. 300ms is enough for 60Hz to have settled.
      Future.delayed(const Duration(milliseconds: 300), onResume);
    }
  }
}