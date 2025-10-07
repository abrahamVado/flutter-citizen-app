import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_citizen_app/src/data/repositories/reports_repository_impl.dart';
import 'package:flutter_citizen_app/src/data/datasources/api_client.dart';
import 'package:flutter_citizen_app/src/data/cache/local_cache.dart';
import 'package:flutter_citizen_app/src/domain/entities/folio_status.dart';
import 'package:flutter_citizen_app/src/domain/entities/report.dart';
import 'package:flutter_citizen_app/src/domain/entities/incident_type.dart';
import 'package:flutter_citizen_app/src/domain/value_objects/auth_token.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.lookupFolioResponse, this.shouldThrow = false});

  FolioStatus? lookupFolioResponse;
  bool shouldThrow;
  int lookupCalls = 0;

  @override
  Future<AuthToken> authenticate({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<List<IncidentType>> fetchIncidentTypes() {
    throw UnimplementedError();
  }

  @override
  Future<FolioStatus> lookupFolio(String folio) async {
    //1.- Registramos la llamada para comprobar que se consulta el API aun con caché.
    lookupCalls += 1;
    if (shouldThrow) {
      throw Exception('network');
    }
    return lookupFolioResponse!;
  }

  @override
  Future<Report> submitReport(Map<String, dynamic> payload) {
    throw UnimplementedError();
  }
}

class _FakeLocalCache implements LocalCache {
  _FakeLocalCache();

  final Map<String, Map<String, dynamic>> _store = {};

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _store[key] = value;
  }
}

void main() {
  const folioHistoryKey = 'folio_history';
  const folio = 'F-123';
  final cachedMap = {
    'items': [
      {
        'folio': folio,
        'status': 'cached',
        'createdAt': DateTime(2023, 01, 01).toIso8601String(),
      },
    ],
  };

  group('ReportsRepositoryImpl.lookupFolio', () {
    test('calls remote lookup even when cache hit', () async {
      //1.- Preparamos la caché con un folio existente.
      final cache = _FakeLocalCache();
      await cache.write(folioHistoryKey, cachedMap);
      final expected = FolioStatus(
        folio: folio,
        status: 'remote',
        lastUpdate: DateTime(2023, 02, 02),
        history: const ['remote'],
      );
      final apiClient = _FakeApiClient(lookupFolioResponse: expected);
      final repository = ReportsRepositoryImpl(apiClient: apiClient, cache: cache);

      //2.- Ejecutamos la consulta esperando priorizar el dato remoto actualizado.
      final result = await repository.lookupFolio(folio);

      expect(apiClient.lookupCalls, 1);
      expect(result, expected);
    });

    test('falls back to cached status when remote lookup fails', () async {
      //1.- Configuramos el estado cacheado como respaldo offline.
      final cache = _FakeLocalCache();
      await cache.write(folioHistoryKey, cachedMap);
      final apiClient = _FakeApiClient(shouldThrow: true);
      final repository = ReportsRepositoryImpl(apiClient: apiClient, cache: cache);

      //2.- Al fallar el API debemos recibir el valor cacheado.
      final result = await repository.lookupFolio(folio);

      expect(apiClient.lookupCalls, 1);
      expect(result.folio, folio);
      expect(result.status, 'cached');
      expect(result.history, const ['Consulta offline']);
    });
  });
}
