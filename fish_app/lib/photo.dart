import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'api/identify_fish_api.dart';
import 'api/meteo_api.dart';

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
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = path.join(directory.path, fileName);

    final image = await _controller!.takePicture();
    await File(image.path).copy(filePath);
    await Gal.putImage(filePath);

    // 2) Charge ou crée le JSON
    final metaFile = File(path.join(directory.path, 'metadata.json'));
    Map<String, dynamic> meta = {};
    if (await metaFile.exists()) {
      meta = json.decode(await metaFile.readAsString()) as Map<String, dynamic>;
    }

    // 3) Ajoute l’entrée avec tous les champs par défaut
    meta[fileName] = {
      'Espece poisson': null,
      'date': null,
      'heure': null,
      'temperature': null,
      'precipitation': null,
      'cloud cover': null,
      'moon': null,
    };

    // 4) Sauvegarde
    await metaFile.writeAsString(json.encode(meta));

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
      // 1) Supprimer la photo du disque
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }

      // 2) Charger et mettre à jour le JSON
      final directory = await getApplicationDocumentsDirectory();
      final metaFile = File(path.join(directory.path, 'metadata.json'));

      if (await metaFile.exists()) {
        // Lire le contenu actuel
        final content = await metaFile.readAsString();
        final Map<String, dynamic> meta =
            json.decode(content) as Map<String, dynamic>;

        // Supprimer la clé liée à cette photo
        final key = path.basename(photoPath);
        if (meta.containsKey(key)) {
          meta.remove(key);
          // Réécrire le JSON mis à jour
          await metaFile.writeAsString(json.encode(meta));
        }
      }

      // 3) Raffraîchir la galerie
      _loadSavedPhotos();
    } catch (e) {
      print('Erreur lors de la suppression de la photo ou du JSON: $e');
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
                  width: 300,
                  height: 400,
                  child: Center(child: CircularProgressIndicator()))
              : FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                          width: 300,
                          height: 400,
                          child: Center(child: CircularProgressIndicator()));
                    }
                    return SizedBox(
                      width: 300,
                      height: 400,
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
  Map<String, dynamic>? _resultData;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final dir = await getApplicationDocumentsDirectory();
    final metaFile = File(path.join(dir.path, 'metadata.json'));
    if (!await metaFile.exists()) return;

    final content = await metaFile.readAsString();
    final Map<String, dynamic> allMeta = json.decode(content);
    final key = path.basename(widget.photoPath);

    if (allMeta.containsKey(key) && allMeta[key] != null) {
      _resultData = Map<String, dynamic>.from(allMeta[key]);
      _isExpanded = false;
      setState(() {});
    }
  }

  Future<void> _callApi() async {
    setState(() {
      _isLoading = true;
      _isExpanded = true;
    });

    final date = DateTime.now();
    final dateStr = '${date.year}-${date.month}-${date.day}';
    final timeStr = '${date.hour}:${date.minute}';

    final String imagePath = widget.photoPath;
    final Map<String, dynamic> data = {
      'Espece poisson': null,
      'date': dateStr,
      'heure': timeStr,
      'temperature': null,
      'precipitation': null,
      'cloud cover': null,
      'uvIndex': null,
      'moon': null,
    };

    // Appel API pour récupérer les données

    try {
      final fishIdentifier = FishIdentifier();
      final String fishName = await fishIdentifier.fetchFishIndetity(imagePath);
      data['Espece poisson'] = fishName;
    } catch (e) {
      print('Erreur lors de l’identification du poisson : $e');
    }

    try {
      final meteoApi = CallMeteo();
      final String meteoData = await meteoApi.fetchWeather();
      final parts = meteoData.split('|');

      if (parts.length >= 7) {       
        data['temperature'] = parts[2];
        data['precipitation'] = parts[3];
        data['cloud cover'] = parts[4];
        data['uvIndex'] = parts[5];
        data['moon'] = parts[6];
      } else {
        print('Format météo inattendu : $meteoData');
      }
    } catch (e) {
      print('Erreur lors de la récupération météo : $e');
    }

    // Sauvegarde dans metadata.json
    try {
      final dir = await getApplicationDocumentsDirectory();
      final metaFile = File(path.join(dir.path, 'metadata.json'));

      Map<String, dynamic> meta = {};
      if (await metaFile.exists()) {
        meta = json.decode(await metaFile.readAsString());
      }

      final key = path.basename(imagePath);
      meta[key] = data;
      await metaFile.writeAsString(json.encode(meta));
    } catch (e) {
      print('Erreur écriture metadata.json : $e');
    }

    setState(() {
      _resultData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // On n'affiche le bouton API que si pas de données
    // ou si l'espèce de poisson n'est pas encore renseignée
    final showApiButton =
        _resultData == null || _resultData!['Espece poisson'] == null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        title: Text('Photo', style: TextStyle(color: colorScheme.onPrimary)),
      ),
      body: Column(
        children: [
          // Affichage de l'image
          Expanded(
            child: Center(
              child: Image.file(
                File(widget.photoPath),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Dropdown "Informations"
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
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                          : (_resultData == null
                              ? const Center(
                                  child: Text(
                                    'Pas encore d’infos',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: _resultData!.entries.map((entry) {
                                      final textValue =
                                          entry.value?.toString() ?? '';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${entry.key}: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                textValue,
                                                style: TextStyle(
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
                                )),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Boutons
          SafeArea(
            top: false, // on ne met le SafeArea qu’en bas
            child: Container(
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
                    ),
                  ),
                  if (showApiButton)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _callApi,
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
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
