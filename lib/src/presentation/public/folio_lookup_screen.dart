import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class FolioLookupScreen extends ConsumerStatefulWidget {
  const FolioLookupScreen({super.key});

  @override
  ConsumerState<FolioLookupScreen> createState() => _FolioLookupScreenState();
}

class _FolioLookupScreenState extends ConsumerState<FolioLookupScreen> {
  final TextEditingController _folioController = TextEditingController();
  String? _result;
  String? _error;

  Future<void> _lookup() async {
    //1.- Limpiamos mensajes previos antes de realizar una nueva consulta.
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      //2.- Ejecutamos el caso de uso para consultar el folio ingresado.
      final folio = await ref.read(lookupFolioProvider)(_folioController.text);
      //3.- Actualizamos el estado local con la respuesta obtenida.
      setState(() {
        _result = 'Folio ${folio.folio} - ${folio.status}';
      });
    } catch (error) {
      //4.- Mostramos el error en caso de que la consulta falle.
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //1.- Renderizamos el formulario de consulta junto con los resultados.
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta de folio')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa el folio entregado en tu reporte anterior.'),
            const SizedBox(height: 12),
            TextField(
              controller: _folioController,
              decoration: const InputDecoration(labelText: 'Folio', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _lookup,
              child: const Text('Buscar'),
            ),
            const SizedBox(height: 24),
            if (_result != null) Text(_result!),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
