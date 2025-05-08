import 'package:geolocator/geolocator.dart';

class GeoLocator {
  Future<String> getCurrentLocation() async {
    bool service = await _isServiceAvailable();
    bool permission = await _hasLocationPermission();

    if (service && permission) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double latitude = position.latitude;
      double longitude = position.longitude;

      print('Latitude: $latitude, Longitude: $longitude');
      return '$latitude|$longitude';
    }

    return 'Localisation unavailable';
  }

  Future<bool> _isServiceAvailable() async {
    bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      print('Service de localisation désactivé');
    }
    return isServiceEnabled;
  }

  Future<bool> _hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      print('Permission refusée');
      return false;
    } else if (permission == LocationPermission.deniedForever) {
      print('Permission refusée définitivement');
      return false;
    }
    return true;
  }
}
