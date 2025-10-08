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

    test('should rely on native enum identity for equality', () {
      //1.- Confirmamos que la igualdad nativa del enum funciona sin necesidad de mezclar EquatableMixin.
      expect(SocialProvider.google == SocialProvider.google, isTrue);
      //2.- Validamos que dos proveedores distintos no son iguales para evitar falsos positivos.
      expect(SocialProvider.google == SocialProvider.apple, isFalse);
    });

    test('should keep expected display name mapping', () {
      //1.- Comprobamos que los nombres visibles se mantienen conforme a la configuración esperada.
      expect(SocialProvider.google.displayName, 'Google');
      expect(SocialProvider.apple.displayName, 'Apple');
      expect(SocialProvider.facebook.displayName, 'Facebook');
    });
  });
}
