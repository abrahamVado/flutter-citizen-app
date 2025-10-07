import 'package:equatable/equatable.dart';

class AuthToken extends Equatable {
  const AuthToken(this.value, {required this.expiresAt});

  final String value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [value, expiresAt];
}
