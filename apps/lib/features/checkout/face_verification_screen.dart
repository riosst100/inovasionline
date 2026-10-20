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

enum _Phase { loading, intro, running, uploading, failed, denied }

/// One-time face check (shared by COD and Paylater). Pops `true` once the recording is uploaded.
class FaceVerificationScreen extends ConsumerStatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  ConsumerState<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends ConsumerState<FaceVerificationScreen> with SingleTickerProviderStateMixin {
  static const _colorHold = Duration(milliseconds: 3200);
  static const _turnAngle = 20.0;
  static const _nodSwing = 16.0;

  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
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
    _spin.dispose();
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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _phase = _Phase.intro;
      });
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
  }

  void _advance() {
    final finished = _step;
    if (finished.key != null) _done.add(finished.key!);
    _holdSince = null;
    _nodMin = _nodMax = null;
    _lastFrameAt = null;
    HapticFeedback.selectionClick();

    final next = _Step.values.indexOf(finished) + 1;
    if (next >= _Step.values.length) {
      _finish();
      return;
    }
    setState(() {
      _step = _Step.values[next];
      _hint = null;
    });
  }

  Future<void> _fail(String message) async {
    if (!mounted || _phase == _Phase.failed) return;
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
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e is DioException && e.error is ApiException
          ? (e.error as ApiException).message
          : 'Gagal mengunggah rekaman. Periksa koneksi Anda.';
      setState(() {
        _phase = _Phase.failed;
        _error = message;
      });
    }
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
    setState(() => _phase = _Phase.intro);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.uploading,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _phase == _Phase.uploading ? null : () => context.pop(false),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
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
    final colorful = _phase == _Phase.running && _step == _Step.color;

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            switch (_phase) {
              _Phase.intro => 'Verifikasi Wajah',
              _Phase.uploading => 'Menyimpan verifikasi...',
              _ => _step.instruction,
            },
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 22,
          child: Text(
            _phase == _Phase.running ? (_hint ?? '') : '',
            style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
              width: diameter,
              height: diameter,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, child) => CustomPaint(
                  painter: _RingPainter(progress: _spin.value, colorful: colorful, done: _phase == _Phase.uploading),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
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
          ),
        ),
        if (_phase == _Phase.uploading)
          const Padding(padding: EdgeInsets.only(bottom: 32), child: CircularProgressIndicator(color: Colors.white))
        else if (_phase == _Phase.intro)
          _intro()
        else
          _progress(),
      ],
    );
  }

  Widget _intro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          const Text(
            'Untuk keamanan pembayaran di tempat, kami perlu memastikan Anda adalah pemilik akun. '
            'Verifikasi hanya dilakukan satu kali dan direkam untuk pengecekan.\n\n'
            'Siapkan ruangan yang terang dan lepas masker atau kacamata hitam.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _start,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Mulai Verifikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    final steps = _Step.values.where((s) => s.key != null).toList();
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
                        ? Colors.white
                        : Colors.white24,
              ),
            ),
        ],
      ),
    );
  }
}

/// Ring around the preview: plain while verifying, a rotating rainbow during the colour check.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.colorful, required this.done});

  final double progress;
  final bool colorful;
  final bool done;

  static const _rainbow = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFE600),
    Color(0xFF34C759),
    Color(0xFF00C7FF),
    Color(0xFF5856FF),
    Color(0xFFFF2D92),
    Color(0xFFFF3B30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (colorful) {
      paint.shader = SweepGradient(
        colors: _rainbow,
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(rect);
    } else {
      paint.color = done ? const Color(0xFF34D399) : Colors.white.withValues(alpha: 0.85);
    }
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.colorful != colorful || old.done != done;
}
