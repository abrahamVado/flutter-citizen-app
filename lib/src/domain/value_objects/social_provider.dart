import 'package:equatable/equatable.dart';

enum SocialProvider with EquatableMixin {
  google('Google'),
  apple('Apple'),
  facebook('Facebook');

  const SocialProvider(this.displayName);

  final String displayName;

  String get id {
    //1.- Reutilizamos el nombre del enumerado para exponer un identificador estable hacia el backend.
    return name;
  }

  @override
  List<Object?> get props => [name];
}
