import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/state/session_controller.dart';
import '../../../domain/usecases/sign_in_with_provider.dart';
import '../../../domain/value_objects/social_provider.dart';
import 'social_sign_in_state.dart';

final socialSignInControllerProvider =
    StateNotifierProvider.autoDispose<SocialSignInController, SocialSignInState>((ref) {
  //1.- Creamos el controlador social reutilizando el caso de uso y la sesión global.
  return SocialSignInController(
    signInWithProvider: ref.watch(signInWithProviderUseCaseProvider),
    sessionController: ref.read(sessionControllerProvider.notifier),
  );
});

class SocialSignInController extends StateNotifier<SocialSignInState> {
  SocialSignInController({
    required SignInWithProvider signInWithProvider,
    required SessionController sessionController,
  })  : _signInWithProvider = signInWithProvider,
        _sessionController = sessionController,
        super(const SocialSignInState.initial());

  final SignInWithProvider _signInWithProvider;
  final SessionController _sessionController;

  Future<void> signIn(SocialProvider provider) async {
    //1.- Evitamos solicitudes múltiples al mismo tiempo para proteger al backend.
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(
      status: SocialSignInStatus.loading,
      errorMessage: null,
      lastProvider: provider,
    );
    try {
      //2.- Solicitamos al backend autenticarse con el proveedor especificado.
      final token = await _signInWithProvider(provider);
      //3.- Notificamos al controlador de sesión para navegar inmediatamente al entorno administrativo.
      _sessionController.markAuthenticated(token);
      //4.- Registramos el éxito para mostrar retroalimentación en la interfaz.
      state = state.copyWith(status: SocialSignInStatus.success, errorMessage: null);
    } on Exception catch (error) {
      //5.- Mantenemos el proveedor que falló y exponemos el mensaje de error.
      state = state.copyWith(status: SocialSignInStatus.error, errorMessage: error.toString());
    }
  }
}
