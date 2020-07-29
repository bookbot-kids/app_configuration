import 'package:flutter_test/flutter_test.dart';

import 'package:app_configuration/app_configuration.dart';

void main() {
  test('load app', () async {
    final app = AppConfiguration();
    await app.initialize();
    assert(app.logger != null);
  });
}
