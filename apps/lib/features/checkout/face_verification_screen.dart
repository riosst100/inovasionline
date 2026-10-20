import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api/api_exception.dart';
import '../../providers/core_providers.dart';

/// Liveness steps, in order. [key] is what the server records for each completed step.
enum _Step {
  align(null, 'Posisikan wajah di dalam lingkaran'),
  closer('come_closer', 'Dekatkan wajah Anda'),
  turnFirst('turn_right', 'Tengok ke kanan'),
  turnSecond('turn_left', 'Sekarang tengok ke kiri'),
  nod('nod', 'Anggukkan kepala'),
  blink('blink', 'Kedipkan mata Anda'),
  color('color_check', 'Tahan sebentar, jangan bergerak');

  const _Step(this.key, this.instruction);

  final String? key;
  final String instruction;
}

enum _Phase { loading, running, uploading, failed, denied }

/// One-time face check (shared by COD and Paylater). Pops `true` once the recording is uploaded.
class FaceVerificationScreen extends ConsumerStatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  ConsumerState<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends ConsumerState<FaceVerificationScreen> with SingleTickerProviderStateMixin {
  static const _flashStep = Duration(milliseconds: 800);
  // Solid full-screen colours that light the face during the colour check, shown in a random order.
  static const _flashPalette = [
    Color(0xFFFF1744),
    Color(0xFF00E676),
    Color(0xFF2979FF),
    Color(0xFFFFEA00),
    Color(0xFFD500F9),
    Color(0xFFFFFFFF),
  ];
  static const _flashCount = 4;
  static final _colorHold = _flashStep * _flashCount;
  static const _turnAngle = 20.0;
  static const _nodSwing = 16.0;

  // Drives the little face that acts out the current instruction.
  late final AnimationController _demo = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  List<Color> _flashColors = const [];
  int _flashIndex = 0;
  Timer? _flashTimer;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast, minFaceSize: 0.2),
  );

  CameraController? _camera;
  _Phase _phase = _Phase.loading;
  _Step _step = _Step.align;
  final List<String> _done = [];
  String? _error;
  String? _hint;
  String? _videoPath;

  bool _busy = false;
  DateTime? _holdSince;

  // Per-step trackers.
  double _firstTurnSign = 0;
  double? _nodMin;
  double? _nodMax;
  bool _blinkSawOpen = false;
  bool _blinkSawClosed = false;
  Duration _colorSeen = Duration.zero;
  DateTime? _lastFrameAt;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  @override
  void dispose() {
    _demo.dispose();
    _flashTimer?.cancel();
    _detector.close();
    final camera = _camera;
    if (camera != null) {
      // Disposing mid-recording drops the file, which is what we want on cancel.
      camera.dispose();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() => _phase = _Phase.loading);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'Perangkat tidak memiliki kamera.');
      final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // ~30 s of video stays well under the 9 MB upload limit at this bitrate.
        videoBitrate: 1200000,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      // CameraX binds Preview + ImageCapture + ImageAnalysis up front; adding VideoCapture makes four
      // use cases, which switches on stream sharing and the preview comes out rotated and stretched.
      // We never take photos, and this call unbinds ImageCapture (it is rebound only on takePicture).
      if (Platform.isAndroid) {
        try {
          await controller.setJpegImageQuality(90);
        } catch (_) {}
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      // The checkout popup already explained the check, so start right away.
      await _start();
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('AccessDenied') || e.code.contains('Permission');
      setState(() {
        _phase = denied ? _Phase.denied : _Phase.failed;
        _error = denied ? 'Izin kamera diperlukan untuk verifikasi wajah.' : (e.description ?? 'Kamera tidak dapat dibuka.');
      });
    }
  }

  // ---------------------------------------------------------------- flow

  Future<void> _start() async {
    final camera = _camera;
    if (camera == null) return;
    _resetTrackers();
    setState(() {
      _phase = _Phase.running;
      _step = _Step.align;
      _done.clear();
      _hint = null;
      _error = null;
    });
    try {
      await camera.startVideoRecording(onAvailable: _onImage);
    } on CameraException catch (e) {
      _fail(e.description ?? 'Gagal merekam video.');
      return;
    }
  }

  void _resetTrackers() {
    _holdSince = null;
    _firstTurnSign = 0;
    _nodMin = _nodMax = null;
    _blinkSawOpen = false;
    _blinkSawClosed = false;
    _colorSeen = Duration.zero;
    _lastFrameAt = null;
    _stopFlash();
  }

  void _startFlash() {
    _flashColors = (List.of(_flashPalette)..shuffle()).take(_flashCount).toList();
    _flashIndex = 0;
    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(_flashStep, (_) {
      if (mounted) setState(() => _flashIndex = (_flashIndex + 1) % _flashColors.length);
    });
  }

  void _stopFlash() {
    _flashTimer?.cancel();
    _flashTimer = null;
    _flashColors = const [];
  }

  /// The solid colour filling the screen right now, or null outside the colour check.
  Color? get _flashColor =>
      _phase == _Phase.running && _step == _Step.color && _flashColors.isNotEmpty ? _flashColors[_flashIndex] : null;

  void _advance() {
    final finished = _step;
    if (finished.key != null) _done.add(finished.key!);
    _holdSince = null;
    _nodMin = _nodMax = null;
    _lastFrameAt = null;
    HapticFeedback.selectionClick();

    final next = _Step.values.indexOf(finished) + 1;
    if (next >= _Step.values.length) {
      _stopFlash();
      _finish();
      return;
    }
    setState(() {
      _step = _Step.values[next];
      _hint = null;
      if (_step == _Step.color) _startFlash();
    });
  }

  Future<void> _fail(String message) async {
    if (!mounted || _phase == _Phase.failed) return;
    _stopFlash();
    final camera = _camera;
    if (camera != null && camera.value.isRecordingVideo) {
      try {
        await camera.stopVideoRecording();
      } on CameraException {
        // The recording is discarded anyway.
      }
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  Future<void> _finish() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      final file = await camera.stopVideoRecording();
      _videoPath = file.path;
    } on CameraException catch (e) {
      _fail(e.description ?? 'Gagal menyimpan rekaman.');
      return;
    }
    await _upload();
  }

  Future<void> _upload() async {
    final path = _videoPath;
    if (path == null) return;
    setState(() {
      _phase = _Phase.uploading;
      _error = null;
    });
    try {
      await ref.read(checkoutServiceProvider).submitFaceVerification(videoPath: path, steps: List.of(_done));
      try {
        File(path).deleteSync();
      } on FileSystemException {
        // Temp file; the OS cleans it up eventually.
      }
      if (!mounted) return;
      await _showSuccess();
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e is DioException && e.error is ApiException
          ? (e.error as ApiException).message
          : 'Gagal mengunggah rekaman. Periksa koneksi Anda.';
      // The server rejected this recording, so "Coba Lagi" records a new one instead of resending it.
      if (e is DioException && e.response != null) _videoPath = null;
      setState(() {
        _phase = _Phase.failed;
        _error = message;
      });
    }
  }

  Future<void> _showSuccess() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF16A34A)),
          title: const Text('Verifikasi Berhasil'),
          content: const Text(
            'Wajah Anda berhasil diverifikasi. Anda tidak perlu verifikasi lagi untuk pesanan berikutnya.',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Lanjutkan Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- detection

  Future<void> _onImage(CameraImage image) async {
    if (_busy || _phase != _Phase.running) return;
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _phase != _Phase.running) return;

      final rotated = input.metadata!.rotation == InputImageRotation.rotation90deg ||
          input.metadata!.rotation == InputImageRotation.rotation270deg;
      final size = rotated ? Size(image.height.toDouble(), image.width.toDouble()) : Size(image.width.toDouble(), image.height.toDouble());
      _onFaces(faces, size);
    } catch (_) {
      // A bad frame is skipped; the next one is tried.
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null || image.planes.length != 1) return null;
    final rotation = InputImageRotationValue.fromRawValue(camera.description.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _setHint(String? hint) {
    if (_hint == hint || !mounted) return;
    setState(() => _hint = hint);
  }

  /// Stays true for [duration] of consecutive frames, so one lucky frame cannot skip a step.
  bool _held(bool condition, [Duration duration = const Duration(milliseconds: 500)]) {
    if (!condition) {
      _holdSince = null;
      return false;
    }
    _holdSince ??= DateTime.now();
    return DateTime.now().difference(_holdSince!) >= duration;
  }

  void _onFaces(List<Face> faces, Size image) {
    final now = DateTime.now();
    final elapsed = _lastFrameAt == null ? Duration.zero : now.difference(_lastFrameAt!);
    _lastFrameAt = now;

    if (faces.isEmpty) {
      _holdSince = null;
      _setHint('Wajah tidak terdeteksi');
      return;
    }
    if (faces.length > 1) {
      _holdSince = null;
      _setHint('Pastikan hanya ada satu wajah');
      return;
    }

    final face = faces.first;
    final box = face.boundingBox;
    final widthFraction = box.width / image.width;
    final centered = (box.center.dx / image.width - 0.5).abs() < 0.2 && (box.center.dy / image.height - 0.5).abs() < 0.22;
    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;

    switch (_step) {
      case _Step.align:
        _setHint(centered ? null : 'Geser wajah ke tengah lingkaran');
        if (_held(centered && widthFraction > 0.22 && yaw.abs() < 15)) _advance();
      case _Step.closer:
        _setHint(widthFraction < 0.42 ? 'Lebih dekat lagi' : null);
        if (_held(widthFraction >= 0.42 && centered && yaw.abs() < 15)) _advance();
      case _Step.turnFirst:
        // The sign of the first turn fixes the direction of the second one, so the
        // check does not depend on how a given device mirrors the front camera.
        if (yaw.abs() >= _turnAngle) {
          _firstTurnSign = yaw.sign;
          _advance();
        }
      case _Step.turnSecond:
        if (yaw * _firstTurnSign <= -_turnAngle) _advance();
      case _Step.nod:
        if (yaw.abs() > 25) {
          _setHint('Hadap lurus ke depan, lalu mengangguk');
          return;
        }
        _setHint(null);
        _nodMin = math.min(_nodMin ?? pitch, pitch);
        _nodMax = math.max(_nodMax ?? pitch, pitch);
        if (_nodMax! - _nodMin! >= _nodSwing) _advance();
      case _Step.blink:
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        if (left == null || right == null) {
          _setHint('Mata tidak terdeteksi');
          return;
        }
        _setHint(null);
        if (!_blinkSawOpen) {
          _blinkSawOpen = left > 0.7 && right > 0.7;
        } else if (!_blinkSawClosed) {
          _blinkSawClosed = left < 0.3 && right < 0.3;
        } else if (left > 0.6 && right > 0.6) {
          _advance();
        }
      case _Step.color:
        // Only counts while the face stays in view, so the colours really light the face up.
        if (centered && yaw.abs() < 20) {
          _setHint(null);
          _colorSeen += elapsed;
          if (_colorSeen >= _colorHold) _advance();
        } else {
          _setHint('Jaga wajah tetap di dalam lingkaran');
        }
    }
  }

  // ----------------------------------------------------------------- UI

  Future<void> _retry() async {
    if (_videoPath != null && _done.length == _Step.values.where((s) => s.key != null).length) {
      // Recording is complete, only the upload failed.
      return _upload();
    }
    _videoPath = null;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return _initCamera();
    }
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final flash = _flashColor;
    return PopScope(
      canPop: _phase != _Phase.uploading,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: flash ?? const Color(0xFF0B1020),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _phase == _Phase.uploading ? null : () => context.pop(false),
                    icon: Icon(Icons.close_rounded, color: _foreground),
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Text colour that stays readable on the current background (dark, or a light flash colour).
  Color get _foreground {
    final flash = _flashColor;
    return flash != null && flash.computeLuminance() > 0.4 ? const Color(0xFF0B1020) : Colors.white;
  }

  Widget _body() {
    return switch (_phase) {
      _Phase.loading => const Center(child: CircularProgressIndicator(color: Colors.white)),
      _Phase.denied || _Phase.failed => _message(),
      _ => _verifier(),
    };
  }

  Widget _message() {
    final denied = _phase == _Phase.denied;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(denied ? Icons.no_photography_rounded : Icons.error_outline_rounded, color: Colors.white70, size: 64),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Terjadi kesalahan.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: denied ? openAppSettings : _retry,
            child: Text(denied ? 'Buka Pengaturan' : 'Coba Lagi'),
          ),
          if (denied)
            TextButton(onPressed: _initCamera, child: const Text('Saya sudah mengizinkan')),
        ],
      ),
    );
  }

  Widget _verifier() {
    final camera = _camera!;
    final width = MediaQuery.sizeOf(context).width;
    final running = _phase == _Phase.running || _phase == _Phase.uploading;
    // Small while aligning, then grows so the face can fill it.
    final diameter = (running && _step != _Step.align) || _phase == _Phase.uploading ? width * 0.88 : width * 0.58;
    final preview = camera.value.previewSize!;
    final fg = _foreground;
    final ringColor = _phase == _Phase.uploading ? const Color(0xFF34D399) : fg.withValues(alpha: 0.85);
    final demo = _phase == _Phase.running ? _step : null;

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            switch (_phase) {
              _Phase.uploading => 'Menyimpan verifikasi...',
              _ => _step.instruction,
            },
            textAlign: TextAlign.center,
            style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 22,
          child: Text(
            _phase == _Phase.running ? (_hint ?? '') : '',
            style: TextStyle(
              color: _flashColor == null ? const Color(0xFFFCD34D) : fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Small face acting out the instruction; keeps its height so the preview does not jump.
        SizedBox(
          height: 72,
          child: _StepDemo.supports(demo)
              ? AnimatedBuilder(
                  animation: _demo,
                  builder: (context, _) => CustomPaint(
                    size: const Size(72, 72),
                    painter: _StepDemo(step: demo!, t: _demo.value, color: fg),
                  ),
                )
              : null,
        ),
        Expanded(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
              width: diameter,
              height: diameter,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 6),
              ),
              child: ClipOval(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: math.min(preview.width, preview.height),
                    height: math.max(preview.width, preview.height),
                    child: CameraPreview(camera),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_phase == _Phase.uploading)
          const Padding(padding: EdgeInsets.only(bottom: 32), child: CircularProgressIndicator(color: Colors.white))
        else
          _progress(),
      ],
    );
  }

  Widget _progress() {
    final steps = _Step.values.where((s) => s.key != null).toList();
    final fg = _foreground;
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final s in steps)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: s == _step ? 22 : 10,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: _done.contains(s.key)
                    ? const Color(0xFF34D399)
                    : s == _step
                        ? fg
                        : fg.withValues(alpha: 0.24),
              ),
            ),
        ],
      ),
    );
  }
}


/// A simple line-drawn face that acts out the current instruction, looping with [t] in 0..1.
class _StepDemo extends CustomPainter {
  _StepDemo({required this.step, required this.t, required this.color});

  final _Step step;
  final double t;
  final Color color;

  static bool supports(_Step? step) =>
      step != null && step != _Step.align && step != _Step.color;

  @override
  void paint(Canvas canvas, Size size) {
    // 0 → 1 → 0 over one loop, eased at both ends.
    final swing = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    final center = size.center(Offset.zero);
    var r = size.shortestSide * 0.36;
    var dx = 0.0;
    var dy = 0.0;
    var eyesClosed = false;

    switch (step) {
      case _Step.closer:
        r *= 0.8 + 0.3 * swing;
      case _Step.turnFirst:
        dx = r * 0.45 * swing;
      case _Step.turnSecond:
        dx = -r * 0.45 * swing;
      case _Step.nod:
        dy = r * 0.32 * math.sin(2 * math.pi * t);
      case _Step.blink:
        eyesClosed = t > 0.45 && t < 0.6;
      case _Step.align:
      case _Step.color:
        break;
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    final head = Rect.fromCenter(center: center, width: r * 1.7, height: r * 2.1);
    canvas.drawOval(head, stroke);

    // Features slide inside the head outline, which reads as the head turning or tilting.
    canvas.save();
    canvas.clipPath(Path()..addOval(head));
    final f = center + Offset(dx, dy);
    for (final side in [-1.0, 1.0]) {
      final eye = f + Offset(side * r * 0.35, -r * 0.2);
      if (eyesClosed) {
        canvas.drawLine(eye - Offset(r * 0.13, 0), eye + Offset(r * 0.13, 0), stroke);
      } else {
        canvas.drawCircle(eye, r * 0.1, fill);
      }
    }
    canvas.drawLine(f + Offset(0, -r * 0.02), f + Offset(0, r * 0.22), stroke);
    canvas.drawArc(Rect.fromCenter(center: f + Offset(0, r * 0.42), width: r * 0.6, height: r * 0.3), 0.15 * math.pi,
        0.7 * math.pi, false, stroke);
    canvas.restore();

    // Arrows spell out the direction.
    final arrowX = r * 1.35;
    void chevron(Offset tip, double dirX, double dirY) {
      final back = Offset(-dirX, -dirY) * (r * 0.28);
      final side = Offset(-dirY, dirX) * (r * 0.22);
      canvas.drawPath(
        Path()
          ..moveTo((tip + back + side).dx, (tip + back + side).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo((tip + back - side).dx, (tip + back - side).dy),
        stroke,
      );
    }

    switch (step) {
      case _Step.turnFirst:
        chevron(center + Offset(arrowX + r * 0.15 * swing, 0), 1, 0);
      case _Step.turnSecond:
        chevron(center + Offset(-arrowX - r * 0.15 * swing, 0), -1, 0);
      case _Step.nod:
        chevron(center + Offset(arrowX, -r * 0.45), 0, -1);
        chevron(center + Offset(arrowX, r * 0.45), 0, 1);
      case _Step.closer:
        chevron(center + Offset(arrowX + r * 0.1 * swing, 0), 1, 0);
        chevron(center + Offset(-arrowX - r * 0.1 * swing, 0), -1, 0);
      case _Step.blink:
      case _Step.align:
      case _Step.color:
        break;
    }
  }

  @override
  bool shouldRepaint(_StepDemo old) => old.t != t || old.step != step || old.color != color;
}
