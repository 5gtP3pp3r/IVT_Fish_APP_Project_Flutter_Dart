import 'package:geolocator/geolocator.dart';

class GeoLocator{
Future<void> getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print('Service de localisation désactivé');
    return;
  }

  // Vérifie les permissions
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print('Permission refusée');
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    print('Permission refusée définitivement');
    return;
  }

  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  double latitude = position.latitude;
  double longitude = position.longitude;

  print('Latitude: $latitude, Longitude: $longitude');
}
}
