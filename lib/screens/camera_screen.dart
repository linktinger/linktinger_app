import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _isInitialized = false;
  bool _initializing = false;
  CameraLensDirection _currentLens = CameraLensDirection.back;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _safeInit();
  }

  Future<void> _safeInit() async {
    // اطلب الإذن أولاً
    if (!await _ensureCameraPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض إذن الكاميرا. افتح الإعدادات للسماح.'),
          ),
        );
      }
      return;
    }
    // ابدأ التهيئة
    await _initializeCamera(_currentLens);
  }

  Future<bool> _ensureCameraPermission() async {
    // iOS/Android: اطلب إذن الكاميرا
    final st = await Permission.camera.request();
    if (st.isGranted) return true;
    if (st.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _initializeCamera(CameraLensDirection lens) async {
    if (_initializing) return;
    _initializing = true;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على أي كاميرا على هذا الجهاز'),
            ),
          );
        }
        return;
      }

      // اختر الكاميرا بحسب الاتجاه المطلوب، أو أول كاميرا إن لم توجد مطابقة
      final CameraDescription cam = _cameras.firstWhere(
        (c) => c.lensDirection == lens,
        orElse: () => _cameras.first,
      );

      // أغلق القديم قبل إنشاء جديد
      await _controller?.dispose();

      final ctrl = CameraController(
        cam,
        ResolutionPreset.high, // high كافية للستوري وغالبًا أخف من max
        enableAudio: false, // فعّلها true فقط للفيديو مع صوت
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _controller = ctrl;
        _currentLens = cam.lensDirection;
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّرت تهيئة الكاميرا: $e')));
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;
    final nextLens = (_currentLens == CameraLensDirection.back)
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _initializeCamera(nextLens);
  }

  Future<void> _takePicture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || ctrl.value.isTakingPicture)
      return;

    try {
      final file = await ctrl.takePicture();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PreviewScreen(imagePath: file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التقاط الصورة: $e')));
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewScreen(imagePath: picked.path),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذّر فتح المعرض: $e')));
    }
  }

  // التعامل مع دورة حياة التطبيق (مهم لـ iOS لمنع كراش عند العودة من الخلفية)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // أوقف الكاميرا عند الخروج
      ctrl.dispose();
      _controller = null;
      _isInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      // أعد التهيئة عند العودة
      _initializeCamera(_currentLens);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized && ctrl != null
          ? Stack(
              children: [
                Positioned.fill(child: CameraPreview(ctrl)),

                // زر الإغلاق (أعلى يسار)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // عناصر التحكم السفلية
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // قلب الكاميرا (يعطّل لو ما عندك إلا واحدة)
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: (_cameras.length >= 2)
                            ? _switchCamera
                            : null,
                      ),

                      // زر التقاط الصورة
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                        ),
                      ),

                      // زر اختيار من المعرض
                      IconButton(
                        icon: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _pickFromGallery,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
