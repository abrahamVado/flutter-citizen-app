import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/state/session_controller.dart';
import '../../../domain/entities/auth_credentials.dart';
import '../../../domain/usecases/register_user.dart';
import 'registration_state.dart';

final registrationControllerProvider =
    StateNotifierProvider.autoDispose<RegistrationController, RegistrationState>((ref) {
  //1.- Creamos el controlador inyectando el caso de uso y el manejador de sesión.
  final controller = RegistrationController(
    registerUser: ref.watch(registerUserProvider),
    sessionController: ref.read(sessionControllerProvider.notifier),
  );
  return controller;
});

class RegistrationController extends StateNotifier<RegistrationState> {
  RegistrationController({required RegisterUser registerUser, required SessionController sessionController})
      : _registerUser = registerUser,
        _sessionController = sessionController,
        super(const RegistrationState.initial());

  final RegisterUser _registerUser;
  final SessionController _sessionController;

  void updateEmail(String value) {
    //1.- Guardamos el correo capturado para construir las credenciales.
    state = state.copyWith(email: value);
  }

  void updatePassword(String value) {
    //1.- Sincronizamos la contraseña escrita con el estado observable.
    state = state.copyWith(password: value);
  }

  Future<void> submit() async {
    //1.- Evitamos procesar múltiples envíos mientras un registro sigue en curso.
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(status: RegistrationStatus.loading, errorMessage: null);
    try {
      //2.- Ejecutamos el caso de uso enviando las credenciales capturadas.
      final token = await _registerUser(
        AuthCredentials(email: state.email, password: state.password),
      );
      //3.- Notificamos a la sesión principal para navegar automáticamente al panel administrativo.
      _sessionController.markAuthenticated(token);
      //4.- Actualizamos el estado indicando éxito y limpiando mensajes previos.
      state = state.copyWith(status: RegistrationStatus.success, errorMessage: null);
    } on Exception catch (error) {
      //5.- Exponemos el error recibido sin alterar las credenciales ingresadas.
      state = state.copyWith(status: RegistrationStatus.error, errorMessage: error.toString());
    }
  }
}
