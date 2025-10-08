import 'src/app/admin_app.dart';
import 'src/app/app_bootstrap.dart';

Future<void> main() async {
  //1.- Inicializamos las dependencias compartidas y montamos la experiencia administrativa protegida.
  await bootstrapApplication(const AdminApp());
}
