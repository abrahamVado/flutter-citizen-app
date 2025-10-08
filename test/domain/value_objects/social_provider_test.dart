import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_citizen_app/src/domain/value_objects/social_provider.dart';

void main() {
  group('SocialProvider', () {
    test('should expose enum name as id', () {
      //1.- Validamos que cada proveedor reutiliza su nombre como identificador estable.
      for (final provider in SocialProvider.values) {
        expect(provider.id, provider.name);
      }
    });

    test('should keep expected display name mapping', () {
      //1.- Comprobamos que los nombres visibles se mantienen conforme a la configuración esperada.
      expect(SocialProvider.google.displayName, 'Google');
      expect(SocialProvider.apple.displayName, 'Apple');
      expect(SocialProvider.facebook.displayName, 'Facebook');
    });
  });
}
