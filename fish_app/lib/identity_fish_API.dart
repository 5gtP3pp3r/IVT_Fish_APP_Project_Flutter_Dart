import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<int> getImageByteSize(String picturePath) async {
  final file = File(picturePath);
  return await file.length();
}

Future<String> getMd5ChecksumBase64(String picturePath) async {
  final file = File(picturePath);
  final bytes = await file.readAsBytes();
  final digest = md5.convert(bytes);
  return base64Encode(digest.bytes);
}

Future<String> getAccessToken(String id, String secret) async {
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
    return data['access_token']; 
  } else {
    throw Exception(
        'Échec de l\'authentification: ${response.statusCode} - ${response.body}');
  }
}

Future<String> uploadPictureCloudResult(String accessToken, String filename,
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

    return '$signedId/$uploadUrl/$contentDisposition'; // réponse concatené, à séparer pour les 2 prochaines requêtes
  } else {
    throw Exception(
        'Échec de l\'upload : ${response.statusCode} - ${response.body}');
  }
}

Future<void> sendPicture(
    String urlCloud, String contentDisposition, String checksum) async {
  final response = await http.put(
    Uri.parse(urlCloud),
    headers: {
      'Content-Disposition': contentDisposition,
      'Content-Md5': checksum,
      'Content-Type': '',
    },
  );

  if (response.statusCode >= 200 && response.statusCode < 300) {
    print('✅ PUT vers Cloud Storage réussi');
  } else {
    print('❌ Échec de l\'upload: ${response.statusCode}');
    print('Réponse: ${response.body}');
    throw Exception('Erreur PUT vers Cloud');
  }
}

Future<String> fishDetection(String signedId, String accessToken) async {
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

    // Retourner le "name": du poisson avec la meilleure "accuracy":
    return fishName;
  } else {
    print('❌ Erreur: ${response.statusCode}');
    print('Réponse: ${response.body}');
    throw Exception('Échec de la détection de poisson');
  }
}

Future<String> identifyFish(String picturePath) async {
  final String filname = picturePath.split("/").last;
  final String mime = "image/jpeg";

  /********* hard code pour tester l'api fishial *********/
  final String id = "ac546059a5a57d1802ce6179";
  final String secret = "55a0a759810b8226526fecd4d5b26518";
  /*******************************************************/

  final int byteSize = await getImageByteSize(picturePath);
  final String checksum = await getMd5ChecksumBase64(picturePath);
  final String accessToken = await getAccessToken(id, secret);

  final String cloudUploadResult = await uploadPictureCloudResult(
      accessToken, filname, mime, byteSize, checksum);

  final signedId = cloudUploadResult.split("/").first;
  final urlCloud = cloudUploadResult.split("/")[1];
  final contentDisposition = cloudUploadResult.split("/").last;

  await sendPicture(urlCloud, contentDisposition, checksum);

  return await fishDetection(signedId, accessToken);
}
