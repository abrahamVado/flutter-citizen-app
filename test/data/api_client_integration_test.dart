import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_citizen_app/src/data/datasources/api_client.dart';
import 'package:flutter_citizen_app/src/data/models/mappers.dart';
import 'package:flutter_citizen_app/src/domain/entities/report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseUrl = 'http://127.0.0.1:8091';
  Process? serverProcess;
  StreamSubscription<String>? stdoutSubscription;
  StreamSubscription<String>? stderrSubscription;

  setUpAll(() async {
    //1.- Iniciamos el backend Go en un puerto aislado para las pruebas.
    serverProcess = await Process.start(
      'go',
      ['run', './cmd/server'],
      workingDirectory: 'backend/go',
      environment: {...Platform.environment, 'PORT': '8091'},
      runInShell: true,
    );
    stdoutSubscription = serverProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => print('backend: $line'));
    stderrSubscription = serverProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => print('backend err: $line'));
    await _waitForServer(Uri.parse('$baseUrl/catalog'));
  });

  tearDownAll(() async {
    //2.- Detenemos el proceso asegurando liberar recursos del sistema.
    serverProcess?.kill(ProcessSignal.sigint);
    try {
      await serverProcess?.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      serverProcess?.kill(ProcessSignal.sigkill);
    }
    await stdoutSubscription?.cancel();
    await stderrSubscription?.cancel();
  });

  test('submits reports and resolves folios concurrently', () async {
    //1.- Instanciamos el cliente apuntando al backend levantado en pruebas.
    final client = ApiClient(baseUrl: baseUrl);

    final authToken = await client.authenticate(email: 'ciudadano@ejemplo.mx', password: 'seguro123');
    expect(authToken.value, isNotEmpty);
    expect(authToken.isExpired, isFalse);

    final incidentTypes = await client.fetchIncidentTypes();
    expect(incidentTypes, isNotEmpty);

    final payloads = List.generate(4, (index) {
      //2.- Serializamos el reporte utilizando el mapper compartido.
      return ReportRequestMapper.toMap(
        ReportRequest(
          incidentTypeId: incidentTypes.first.id,
          description: 'Reporte $index',
          contactEmail: 'ciudadano@ejemplo.mx',
          contactPhone: '555000$index',
          latitude: 19.4326 + index * 0.001,
          longitude: -99.1332 - index * 0.001,
          address: 'Centro CDMX',
        ),
      );
    });

    //3.- Disparamos los envíos de reportes en paralelo para ejercitar el worker pool.
    final reports = await Future.wait(payloads.map(client.submitReport));
    expect(reports, hasLength(payloads.length));

    //4.- Buscamos los folios obtenidos verificando que cada uno responde correctamente.
    final statuses = await Future.wait(reports.map((report) => client.lookupFolio(report.id)));
    expect(statuses.map((status) => status.folio), containsAll(reports.map((report) => report.id)));
  });
}

Future<void> _waitForServer(Uri uri) async {
  //1.- Intentamos conectar repetidamente hasta que el servicio responda satisfactoriamente.
  final client = HttpClient();
  for (var attempt = 0; attempt < 25; attempt += 1) {
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 500) {
        await response.drain();
        client.close(force: true);
        return;
      }
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  client.close(force: true);
  fail('El backend Go no inició a tiempo');
}
