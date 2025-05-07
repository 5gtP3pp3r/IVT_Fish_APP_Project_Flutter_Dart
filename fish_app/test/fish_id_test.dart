import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fish_app/api/identify_fish_api.dart';

void main() {
  test('Test de reconnaissance de poisson', () async {
    //await dotenv.load(fileName: ".env");

    const picturePath =
        "test/photosTest/brochet2.jpg"; // Chemin absolu vers une vraie image sur ton disque

    expect(File(picturePath).existsSync(), isTrue,
        reason: 'Le fichier image doit exister');

    final identifier = FishIdentifier();
    final result = await identifier.identifyFish(picturePath);

    print('Résultat: $result'); // print console VSCode
    expect(result.isNotEmpty, true);
  });
}
