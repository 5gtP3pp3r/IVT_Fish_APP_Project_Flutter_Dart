import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fish_app/api/meteo_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Test de fetch météo', (WidgetTester tester) async {
  
    final callMeteo = CallMeteo();
    final result = await callMeteo.fetchWeather();

    print('Résultat: $result'); // print console VSCode
    expect(result.isNotEmpty, true);
  });
}