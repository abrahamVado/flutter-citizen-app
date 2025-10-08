import 'package:equatable/equatable.dart';

enum RecoverPasswordStatus { idle, loading, success, error }

class RecoverPasswordState extends Equatable {
  const RecoverPasswordState({
    required this.email,
    required this.status,
    this.errorMessage,
  });

  const RecoverPasswordState.initial()
      : this(
          email: '',
          status: RecoverPasswordStatus.idle,
        );

  final String email;
  final RecoverPasswordStatus status;
  final String? errorMessage;

  bool get isLoading {
    //1.- Indicamos si debemos bloquear el botón mientras se procesa el envío.
    return status == RecoverPasswordStatus.loading;
  }

  RecoverPasswordState copyWith({
    String? email,
    RecoverPasswordStatus? status,
    String? errorMessage,
  }) {
    //1.- Generamos un nuevo estado sin mutar el actual para mantener la trazabilidad.
    return RecoverPasswordState(
      email: email ?? this.email,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, status, errorMessage];
}
