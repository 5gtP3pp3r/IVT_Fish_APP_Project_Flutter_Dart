import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
//import 'package:fish_app/config/fishial_key_config.dart';

class FishIdentifier {
  Future<String> identifyFish(String picturePath) async {
    final String filname = picturePath.split("/").last;
    const String mime = "image/jpeg";

    // Clés via fichier .env
    // final String id = FishialConfig.clientId;
    // final String secret = FishialConfig.clientSecret;

    // Clés via env.json
    final String id = await _getKey("FISHIAL_CLIENT_ID");
    final String secret = await _getKey("FISHIAL_CLIENT_SECRET");

    final int byteSize = await _getImageByteSize(picturePath);
    final String checksum = await _getMd5ChecksumBase64(picturePath);
    final String accessToken = await _getAccessToken(id, secret);
    final String cloudUploadResult = await _uploadPictureCloudResult(
        accessToken, filname, mime, byteSize, checksum);

    final signedId = cloudUploadResult.split("|").first;
    final urlCloud = cloudUploadResult.split("|")[1];
    final contentDisposition = cloudUploadResult.split("|").last;

    await _sendPicture(picturePath, urlCloud, contentDisposition, checksum);

    return await _fishDetection(signedId, accessToken);
  }

  /************ Méthode temp extraction clés via .json ***********/
  /***************** tester si .env fonctionne *******************/
  Future<String> _getKey(String key) async {
    final file = File('env.json');
    String contents = await file.readAsString();
    Map<String, dynamic> json = jsonDecode(contents);

    if (!json.containsKey(key)) {
      //print('Clé introuvable');
      throw Exception('Clé $key non trouvée dans le fichier JSON');
    }

    //print('Clé $key ${json[key].toString()}');
    return json[key].toString();
  }
  /****************************************************************/

  Future<int> _getImageByteSize(String picturePath) async {
    final file = File(picturePath);
    return await file.length();
  }

  Future<String> _getMd5ChecksumBase64(String picturePath) async {
    final file = File(picturePath);
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return base64Encode(digest.bytes);
  }

  Future<String> _getAccessToken(String id, String secret) async {
    final url = Uri.parse('https://api-users.fishial.ai/v1/auth/token');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'client_id': id,
        'client_secret': secret,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      //print('Access_token ${data['access_token']}');
      return data['access_token'];
    } else {
      //print('Échec de l\'authentification');
      throw Exception(
          'Échec de l\'authentification: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _uploadPictureCloudResult(String accessToken, String filename,
      String mime, int byteSize, String checksum) async {
    final url = Uri.parse('https://api.fishial.ai/v1/recognition/upload');
    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'blob': {
          'filename': filename,
          'content_type': mime,
          'byte_size': byteSize,
          'checksum': checksum,
        }
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      final signedId = json['signed-id'];
      final uploadUrl = json['direct-upload']['url'];
      final contentDisposition =
          json['direct-upload']['headers']['Content-Disposition'];

      // print('signed_id $signedId');
      // print('upload url $uploadUrl');
      // print('content-disposotion $contentDisposition');

      return '$signedId|$uploadUrl|$contentDisposition'; // réponse concatené, à séparer pour les 2 prochaines requêtes
    } else {
      //print('Échec Post au cloud');
      throw Exception(
          'Échec de l\'upload : ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> _sendPicture(String picturePath, String urlCloud,
      String contentDisposition, String checksum) async {
    final response = await http.put(
      Uri.parse(urlCloud),
      headers: {
        'Content-Disposition': contentDisposition,
        'Content-Md5': checksum,
        'Content-Type': '',
      },
      body: File(picturePath).readAsBytesSync(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      //print('PUT vers Cloud Storage réussi');
    } else {
      // print('Échec de l\'upload: ${response.statusCode}');
      // print('Réponse: ${response.body}');
      throw Exception('Erreur PUT vers Cloud');
    }
  }

  Future<String> _fishDetection(String signedId, String accessToken) async {
    final url = 'https://api.fishial.ai/v1/recognition/image?q=$signedId';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final results = data['results'] as List;

      double highestAccuracy = 0.0;
      String fishName = '';

      // Boucle des résultats pour trouver le "name": du poisson avec la meilleure "accuracy":
      for (var result in results) {
        final species = result['species'] as List;
        for (var fish in species) {
          final accuracy = fish['accuracy'] as double;
          if (accuracy > highestAccuracy) {
            highestAccuracy = accuracy;
            fishName = fish['name'];
          }
        }
      }

      return fishName;
    } else {
      // print('Erreur: ${response.statusCode}');
      // print('Réponse: ${response.body}');
      throw Exception('Échec de la détection de poisson');
    }
  }
}
