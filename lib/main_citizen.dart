import 'src/app/app_bootstrap.dart';
import 'src/app/citizen_app.dart';

Future<void> main() async {
  //1.- Inicializamos la infraestructura compartida y lanzamos la experiencia pública.
  await bootstrapApplication(const CitizenApp());
}
