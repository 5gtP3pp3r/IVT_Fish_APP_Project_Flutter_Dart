import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show rootBundle;

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  XFile? _photo;
  List<String> _photosFromJson = [];
  bool _photosLoaded = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadPhotosFromJson();
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
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller!.initialize();
    
    // N'actualisez que la partie caméra et non toute l'interface
    if (mounted) {
      setState(() {
        // Ne mettre à jour que les variables liées à la caméra
      });
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _initializeSelectedCamera();
  }

  Future<void> _takePhoto() async {
    await _initializeControllerFuture;
    final image = await _controller!.takePicture();

    setState(() {
      _photo = image;
      // Ici, vous pourriez ajouter la photo à la galerie si nécessaire
    });
  }

  Future<void> _loadPhotosFromJson() async {
    if (_photosLoaded) return;
    
    try {
      final String jsonString =
          await rootBundle.loadString('assets/photos/photos.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      
      setState(() {
        _photosFromJson = jsonData.cast<String>();
        _photosLoaded = true;
      });
    } catch (e) {
      print('Erreur lors du chargement des photos JSON: $e');
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
          
          // Section galerie
          Expanded(
            child: _photosLoaded
                ? PhotoGallery(photos: _photosFromJson)
                : const Center(child: CircularProgressIndicator()),
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
    if (photos.isEmpty) {
      return const Center(child: Text('Aucune photo disponible'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        return Image.asset(
          photos[index],
          fit: BoxFit.cover,
        );
      },
    );
  }
}