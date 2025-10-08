import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../design/shadcn/components/shadcn_button.dart';
import '../design/shadcn/components/shadcn_card.dart';
import '../design/shadcn/components/shadcn_input.dart';
import '../design/shadcn/components/shadcn_page.dart';

class FolioLookupScreen extends ConsumerStatefulWidget {
  const FolioLookupScreen({super.key});

  @override
  ConsumerState<FolioLookupScreen> createState() => _FolioLookupScreenState();
}

class _FolioLookupScreenState extends ConsumerState<FolioLookupScreen> {
  final TextEditingController _folioController = TextEditingController();
  String? _result;
  String? _error;

  @override
  void dispose() {
    //1.- Liberamos el controlador del campo de texto antes de destruir el estado.
    _folioController.dispose();
    super.dispose();
  }

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
    return ShadcnPage(
      title: 'Consulta de folio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ingresa el folio entregado en tu reporte anterior.'),
          const SizedBox(height: 16),
          ShadcnCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShadcnInput(
                  controller: _folioController,
                  label: 'Folio',
                  hintText: 'Ej. CR-2048',
                ),
                const SizedBox(height: 16),
                ShadcnButton(
                  label: 'Buscar',
                  onPressed: _lookup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_result != null)
            ShadcnCard(
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_result!)),
                ],
              ),
            ),
          if (_error != null)
            ShadcnCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
