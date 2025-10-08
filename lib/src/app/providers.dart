import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache/local_cache.dart';
import '../data/datasources/api_client.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/repositories/reports_repository.dart';
import '../domain/usecases/authenticate_user.dart';
import '../domain/usecases/get_incident_types.dart';
import '../domain/usecases/lookup_folio.dart';
import '../domain/usecases/recover_password.dart';
import '../domain/usecases/register_user.dart';
import '../domain/usecases/sign_in_with_provider.dart';
import '../domain/usecases/submit_report.dart';
import 'state/session_controller.dart';

final localCacheProvider = Provider<LocalCache>((ref) {
  //1.- Indicamos que este provider debe ser sobrescrito durante el bootstrap.
  throw UnimplementedError('LocalCache no configurado');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  //1.- Indicamos que este provider debe ser sobrescrito durante el bootstrap.
  throw UnimplementedError('ApiClient no configurado');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  //1.- Indicamos que este provider debe ser sobrescrito durante el bootstrap.
  throw UnimplementedError('AuthRepository no configurado');
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  //1.- Indicamos que este provider debe ser sobrescrito durante el bootstrap.
  throw UnimplementedError('CatalogRepository no configurado');
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  //1.- Indicamos que este provider debe ser sobrescrito durante el bootstrap.
  throw UnimplementedError('ReportsRepository no configurado');
});

final authenticateUserProvider = Provider<AuthenticateUser>((ref) {
  //1.- Inyectamos la implementación concreta del repositorio y creamos el caso de uso.
  return AuthenticateUser(authRepository: ref.watch(authRepositoryProvider));
});

final registerUserProvider = Provider<RegisterUser>((ref) {
  //1.- Construimos el caso de uso de registro con el repositorio correspondiente.
  return RegisterUser(authRepository: ref.watch(authRepositoryProvider));
});

final recoverPasswordProvider = Provider<RecoverPassword>((ref) {
  //1.- Exponemos la acción de recuperación de contraseña reutilizando el repositorio de autenticación.
  return RecoverPassword(authRepository: ref.watch(authRepositoryProvider));
});

final signInWithProviderUseCaseProvider = Provider<SignInWithProvider>((ref) {
  //1.- Disponemos del caso de uso de autenticación social para los controladores de presentación.
  return SignInWithProvider(authRepository: ref.watch(authRepositoryProvider));
});

final submitReportProvider = Provider<SubmitReport>((ref) {
  //1.- Inyectamos el repositorio de reportes y regresamos el caso de uso.
  return SubmitReport(reportsRepository: ref.watch(reportsRepositoryProvider));
});

final getIncidentTypesProvider = Provider<GetIncidentTypes>((ref) {
  //1.- Inyectamos el repositorio de catálogos para obtener los tipos de incidentes.
  return GetIncidentTypes(catalogRepository: ref.watch(catalogRepositoryProvider));
});

final lookupFolioProvider = Provider<LookupFolio>((ref) {
  //1.- Inyectamos el repositorio de reportes para consultar un folio por identificador.
  return LookupFolio(reportsRepository: ref.watch(reportsRepositoryProvider));
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  //1.- Construimos el controlador de sesión partiendo del caso de uso de autenticación.
  return SessionController(authenticateUser: ref.watch(authenticateUserProvider));
});
