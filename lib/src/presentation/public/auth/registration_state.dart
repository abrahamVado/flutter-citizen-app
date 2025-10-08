import 'package:equatable/equatable.dart';

enum RegistrationStatus { idle, loading, success, error }

class RegistrationState extends Equatable {
  const RegistrationState({
    required this.email,
    required this.password,
    required this.status,
    this.errorMessage,
  });

  const RegistrationState.initial()
      : this(
          email: '',
          password: '',
          status: RegistrationStatus.idle,
        );

  final String email;
  final String password;
  final RegistrationStatus status;
  final String? errorMessage;

  bool get isLoading {
    //1.- Verificamos si el flujo se encuentra procesando una petición remota.
    return status == RegistrationStatus.loading;
  }

  RegistrationState copyWith({
    String? email,
    String? password,
    RegistrationStatus? status,
    String? errorMessage,
  }) {
    //1.- Retornamos una nueva instancia asegurando inmutabilidad en los controladores.
    return RegistrationState(
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, password, status, errorMessage];
}
