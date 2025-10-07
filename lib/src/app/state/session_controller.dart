import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_credentials.dart';
import '../../domain/usecases/authenticate_user.dart';
import '../../domain/value_objects/auth_token.dart';

class SessionState extends Equatable {
  const SessionState({
    required this.status,
    this.token,
    this.errorMessage,
  });

  const SessionState.initial() : this(status: SessionStatus.signedOut);

  final SessionStatus status;
  final AuthToken? token;
  final String? errorMessage;

  SessionState copyWith({
    SessionStatus? status,
    AuthToken? token,
    String? errorMessage,
  }) {
    //1.- Creamos un nuevo estado respetando los valores anteriores para mantener inmutabilidad.
    return SessionState(
      status: status ?? this.status,
      token: token ?? this.token,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, token, errorMessage];
}

enum SessionStatus { initializing, signedOut, authenticated, error }

class SessionController extends StateNotifier<SessionState> {
  SessionController({required AuthenticateUser authenticateUser})
      : _authenticateUser = authenticateUser,
        super(const SessionState.initial());

  final AuthenticateUser _authenticateUser;

  Future<void> signIn(AuthCredentials credentials) async {
    //1.- Actualizamos el estado a inicializando para mostrar indicadores en la UI.
    state = state.copyWith(status: SessionStatus.initializing, errorMessage: null);
    try {
      //2.- Ejecutamos el caso de uso de autenticación utilizando las credenciales entregadas.
      final token = await _authenticateUser(credentials);
      //3.- Publicamos el token exitoso y marcamos la sesión como autenticada.
      state = state.copyWith(status: SessionStatus.authenticated, token: token);
    } on Exception catch (error) {
      //4.- Ante cualquier error exponemos un mensaje legible y limpiamos el token previo.
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: error.toString(),
        token: null,
      );
    }
  }

  void signOut() {
    //1.- Limpiamos la sesión y exponemos el estado firmado fuera para ocultar rutas administrativas.
    state = const SessionState.initial();
  }
}
