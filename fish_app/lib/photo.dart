import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  XFile? _photo;
  List<String> _savedPhotos = [];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null || _controller?.value.isInitialized == false)
      return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeSelectedCamera();
    }
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
    _requestPermissions().then((_) {
      _loadSavedPhotos();
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.storage.request();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _selectedCameraIndex = 0;
    await _initializeSelectedCamera();
  }

  Future<void> _initializeSelectedCamera() async {
    _controller?.dispose();

    final selectedCamera = _cameras[_selectedCameraIndex];

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
    );

    _initializeControllerFuture = _controller!.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _initializeSelectedCamera();
  }

  Future<void> _takePhoto() async {
    await _initializeControllerFuture;

    final directory = await getApplicationDocumentsDirectory();
    final String fileName =
        'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = path.join(directory.path, fileName);

    final image = await _controller!.takePicture();

    await File(image.path).copy(filePath);

    await Gal.putImage(filePath);

    setState(() {
      _photo = XFile(filePath);
    });

    _loadSavedPhotos();
  }

  Future<void> _loadSavedPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = Directory(directory.path)
          .listSync()
          .where((file) =>
              file.path.endsWith('.jpg') ||
              file.path.endsWith('.png') ||
              file.path.endsWith('.jpeg'))
          .map((f) => f.path)
          .toList();

      setState(() {
        _savedPhotos = files;
      });
    } catch (e) {
      print('Erreur lors du chargement des photos: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caméra + Galerie')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Section caméra
          _controller == null
              ? const SizedBox(
                  width: 330,
                  height: 330,
                  child: Center(child: CircularProgressIndicator()))
              : FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                          width: 330,
                          height: 330,
                          child: Center(child: CircularProgressIndicator()));
                    }
                    return SizedBox(
                      width: 330,
                      height: 330,
                      child: CameraPreview(_controller!),
                    );
                  },
                ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _switchCamera,
                icon: const Icon(Icons.cameraswitch),
                label: const Text('Caméra'),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Photo'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Expanded(
            child: _savedPhotos.isEmpty
                ? const Center(child: Text('Aucune photo disponible'))
                : PhotoGallery(photos: _savedPhotos),
          ),
        ],
      ),
    );
  }
}

class PhotoGallery extends StatelessWidget {
  final List<String> photos;

  const PhotoGallery({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        return Image.file(
          File(photos[index]),
          fit: BoxFit.cover,
        );
      },
    );
  }
}
