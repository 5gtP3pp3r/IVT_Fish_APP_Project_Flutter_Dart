import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class PhotoPage extends StatefulWidget {
  @override
  PhotoPageState createState() => PhotoPageState();
}

class PhotoPageState extends State<PhotoPage> {
  List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (_photos.isNotEmpty) return;
    print('Début du chargement JSON...');
    try {
      final String jsonString =
          await rootBundle.loadString('assets/photos/photos.json');
      print('Contenu JSON chargé.');

      final List<dynamic> jsonData = json.decode(jsonString);
      print('JSON décodé.');

      setState(() {
        _photos = jsonData.cast<String>();
      });
      print('Photos mises à jour : ${_photos.length} éléments');
    } catch (e) {
      print('Erreur pendant le chargement des photos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Photos')),
      body: _photos.isEmpty
          ? Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                return Image.asset(_photos[index], fit: BoxFit.cover);
              },
            ),
    );
  }
}
