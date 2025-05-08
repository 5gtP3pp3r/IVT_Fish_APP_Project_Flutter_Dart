import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:fish_app/api/geo_locator.dart';

class CallMeteo {
  Future<String> fetchWeather() async {
    final String apiKey = await _getKey('METEO_API_KEY');

    final String location = await _getCoordinates();
    final coordinates = location.split("|");

    final double latitude = double.parse(coordinates[0]);
    final double longitude = double.parse(coordinates[1]);

    final url = Uri.parse(
      'https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/'
      '$latitude,$longitude'
      '?unitGroup=metric'
      '&elements=datetime,latitude,longitude,temp,preciptype,cloudcover,uvindex,moonphase'
      '&include=current'
      '&key=$apiKey'
      '&contentType=json',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final dayData = data['days'][0];
      final current = data['currentConditions'];

      final String dateTime = dayData['datetime'];
      final String currentTime = current['datetime'];
      final String temp = current['temp'].toString();
      final String preciptype = current['preciptype']?.join(', ') ?? 'aucune';
      final String cloudcover = current['cloudcover'].toString();
      final String uvindex = current['uvindex'].toString();
      final String moonphase = current['moonphase'].toString();

      print('Date $dateTime');
      print('heure $currentTime');
      print('Température $temp');
      print('Précipitation $preciptype');
      print('Couverture nuageuse $cloudcover');
      print('Indice UV $uvindex');
      print('Phase lunaire $moonphase');

      return '$dateTime|$currentTime|$temp|$preciptype|$cloudcover|$uvindex|$moonphase';
    }

    print('Erreur lors de la requête météo : ${response.statusCode}');
    return 'Erreur lors de la requête météo';
  }
}

Future<String> _getCoordinates() async {
  var geolocator = GeoLocator();
  String coordinates = await geolocator.getCurrentLocation();

  if (coordinates == 'Localisation unavailable') {
    print('Localisation introuvable');
    return 'Localisation unavailable';
  }

  print('Coordonnée: $coordinates');
  return coordinates;
}

Future<String> _getKey(String key) async {
  final contents = await rootBundle.loadString('env.json');
  Map<String, dynamic> json = jsonDecode(contents);

  if (!json.containsKey(key)) {
    //print('Clé introuvable');
    throw Exception('Clé $key non trouvée dans le fichier JSON');
  }

  //print('Clé $key ${json[key].toString()}');
  return json[key].toString();
}
