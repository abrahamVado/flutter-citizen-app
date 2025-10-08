enum SocialProvider {
  google('Google'),
  apple('Apple'),
  facebook('Facebook');

  const SocialProvider(this.displayName);

  final String displayName;

  String get id {
    //1.- Reutilizamos el nombre del enumerado para exponer un identificador estable hacia el backend.
    return name;
  }
}
