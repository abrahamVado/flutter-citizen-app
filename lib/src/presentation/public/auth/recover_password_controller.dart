import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/usecases/recover_password.dart';
import 'recover_password_state.dart';

final recoverPasswordControllerProvider =
    StateNotifierProvider.autoDispose<RecoverPasswordController, RecoverPasswordState>((ref) {
  //1.- Creamos el controlador con el caso de uso que envía los correos de restablecimiento.
  return RecoverPasswordController(recoverPassword: ref.watch(recoverPasswordProvider));
});

class RecoverPasswordController extends StateNotifier<RecoverPasswordState> {
  RecoverPasswordController({required RecoverPassword recoverPassword})
      : _recoverPassword = recoverPassword,
        super(const RecoverPasswordState.initial());

  final RecoverPassword _recoverPassword;

  void updateEmail(String value) {
    //1.- Actualizamos el correo que recibirá las instrucciones de recuperación.
    state = state.copyWith(email: value);
  }

  Future<void> submit() async {
    //1.- Evitamos envíos duplicados en paralelo.
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(status: RecoverPasswordStatus.loading, errorMessage: null);
    try {
      //2.- Invocamos el caso de uso responsable de disparar el correo.
      await _recoverPassword(state.email);
      //3.- Mostramos al usuario que el mensaje fue enviado exitosamente.
      state = state.copyWith(status: RecoverPasswordStatus.success, errorMessage: null);
    } on Exception catch (error) {
      //4.- Registramos la falla para que la interfaz muestre el mensaje correspondiente.
      state = state.copyWith(status: RecoverPasswordStatus.error, errorMessage: error.toString());
    }
  }
}
