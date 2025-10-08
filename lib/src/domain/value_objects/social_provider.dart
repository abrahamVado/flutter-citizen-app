//1.- Enumeramos los proveedores sociales disponibles junto a su nombre visible.
enum SocialProvider {
  google('Google'),
  apple('Apple'),
  facebook('Facebook');

  //2.- Asociamos un nombre para mostrar reutilizable en la interfaz de usuario.
  const SocialProvider(this.displayName);

  final String displayName;

  String get id {
    //1.- Reutilizamos el nombre del enumerado para exponer un identificador estable hacia el backend.
    return name;
  }
}
