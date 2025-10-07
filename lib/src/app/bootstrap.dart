import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache/local_cache.dart';
import '../data/datasources/api_client.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/catalog_repository_impl.dart';
import '../data/repositories/reports_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/repositories/reports_repository.dart';
import 'providers.dart';

Future<List<Override>> buildAppOverrides() async {
  //1.- Creamos la caché local que simula el comportamiento de DataStore/Room.
  final cache = InMemoryLocalCache();
  //2.- Configuramos el cliente de red que encapsula las peticiones REST.
  final apiClient = ApiClient();
  //3.- Registramos las implementaciones concretas que se expondrán a la capa de dominio.
  return [
    localCacheProvider.overrideWithValue(cache),
    apiClientProvider.overrideWithValue(apiClient),
    authRepositoryProvider.overrideWithValue(
      AuthRepositoryImpl(apiClient: apiClient, cache: cache),
    ),
    catalogRepositoryProvider.overrideWithValue(
      CatalogRepositoryImpl(apiClient: apiClient, cache: cache),
    ),
    reportsRepositoryProvider.overrideWithValue(
      ReportsRepositoryImpl(apiClient: apiClient, cache: cache),
    ),
  ];
}
