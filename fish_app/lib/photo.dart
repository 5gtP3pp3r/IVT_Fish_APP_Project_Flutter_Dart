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
    if (_controller == null || _controller?.value.isInitialized == false) {
      return;
    }

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

  Future<void> _deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        _loadSavedPhotos(); // Rafraîchir la galerie après suppression
      }
    } catch (e) {
      print('Erreur lors de la suppression de la photo: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caméra + Galerie'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Expanded(
            child: _savedPhotos.isEmpty
                ? const Center(child: Text('Aucune photo disponible'))
                : PhotoGallery(
                    photos: _savedPhotos,
                    onDelete: _deletePhoto,
                  ),
          ),
        ],
      ),
    );
  }
}

class PhotoGallery extends StatelessWidget {
  final List<String> photos;
  final Function(String) onDelete;
  const PhotoGallery({super.key, required this.photos, required this.onDelete});

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
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PhotoDetailScreen(
                  photoPath: photos[index],
                  onDelete: () {
                    onDelete(photos[index]); // <-- suppression directe
                    Navigator.pop(context);
                  },
                  onApiCall: () {
                    // Cette fonction sera implémentée plus tard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('API Call sera implémenté plus tard')),
                    );
                  },
                ),
              ),
            );
          },
          child: Image.file(
            File(photos[index]),
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class PhotoDetailScreen extends StatefulWidget {
  final String photoPath;
  final VoidCallback onDelete;
  final VoidCallback onApiCall;

  const PhotoDetailScreen({
    Key? key,
    required this.photoPath,
    required this.onDelete,
    required this.onApiCall,
  }) : super(key: key);

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  bool _isLoading = false;
  bool _isExpanded = false;
  Map<String, String>? _resultData;

  Future<void> _callApi() async {
    setState(() {
      _isLoading = true;
      _isExpanded =
          true; // Ouvrir automatiquement le dropdown lors de l'appel API
    });

    try {
      // Simulation d'appel API - remplacez par votre implémentation existante
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _resultData = {
          "Nom du poisson": "Bar commun (Dicentrarchus labrax)",
          "Cycle lunaire": "Pleine lune (98%)",
          "Marée": "Haute marée - 4.2m",
          "Météo": "Ensoleillé, 22°C",
          "Saison de pêche": "Optimale",
          "Habitat": "Eaux côtières, profondeur moyenne",
        };
      });
    } catch (e) {
      setState(() {
        _resultData = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        title: Text('Photo', style: TextStyle(color: colorScheme.onPrimary)),
      ),
      body: Column(
        children: [
          // Image section - flexible pour prendre l'espace disponible
          Expanded(
            child: Center(
              child: Image.file(
                File(widget.photoPath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Section dropdown pour les informations
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                // En-tête du dropdown (toujours visible)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Informations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        // Icône pour indiquer l'état du dropdown
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Contenu du dropdown (visible uniquement si _isExpanded est true)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isExpanded
                      ? (_isLoading ? 100 : (_resultData != null ? 250 : 80))
                      : 0,
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    opacity: _isExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _resultData == null
                              ? const Center(
                                  child: Text(
                                    'Cliquez sur "Appel API" pour obtenir les informations sur cette photo',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    children: _resultData!.entries.map((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${entry.key}: ",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                entry.value,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Boutons
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _callApi,
                  icon: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSecondary,
                          ),
                        )
                      : const Icon(Icons.api),
                  label: Text(_isLoading ? 'Chargement...' : 'Appel API'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
