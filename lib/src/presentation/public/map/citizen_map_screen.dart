import 'package:flutter/material.dart';

import '../report/report_form_sheet.dart';

class CitizenMapScreen extends StatelessWidget {
  const CitizenMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //1.- Renderizamos un contenedor que simula el mapa y permite confirmar la ubicación.
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona la ubicación')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('Mapa ciudadano (Google Maps Compose equivalente)'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                //1.- Mostramos el formulario en un bottom sheet similar a la web actual.
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ReportFormSheet(),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Confirmar ubicación'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
