import 'package:equatable/equatable.dart';

import '../../../domain/value_objects/social_provider.dart';

enum SocialSignInStatus { idle, loading, success, error }

class SocialSignInState extends Equatable {
  const SocialSignInState({
    required this.status,
    this.errorMessage,
    this.lastProvider,
  });

  const SocialSignInState.initial()
      : this(status: SocialSignInStatus.idle);

  final SocialSignInStatus status;
  final String? errorMessage;
  final SocialProvider? lastProvider;

  bool get isLoading {
    //1.- Indicamos cuando se está validando un proveedor para bloquear nuevos intentos.
    return status == SocialSignInStatus.loading;
  }

  SocialSignInState copyWith({
    SocialSignInStatus? status,
    String? errorMessage,
    SocialProvider? lastProvider,
  }) {
    //1.- Reemplazamos selectivamente los valores para propagar el nuevo estado a la UI.
    return SocialSignInState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      lastProvider: lastProvider ?? this.lastProvider,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, lastProvider];
}
