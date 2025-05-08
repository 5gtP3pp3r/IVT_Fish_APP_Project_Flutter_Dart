import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fish_app/api/geo_locator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test réel du GeoLocator', (WidgetTester tester) async {
    final geo = GeoLocator();
    final result = await geo.getCurrentLocation();

    print('🛰 Résultat de géolocalisation: $result');
    expect(result, contains('|'));
  });
}
