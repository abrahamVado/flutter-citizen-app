import 'package:flutter/material.dart';

import '../../design/shadcn/components/shadcn_button.dart';
import '../../design/shadcn/components/shadcn_card.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoAssignIncidents = false;
  TimeOfDay _digestTime = const TimeOfDay(hour: 8, minute: 0);

  Future<void> _selectDigestTime(BuildContext context) async {
    //1.- Abrimos el selector nativo para elegir la hora de envío del resumen diario.
    final selected = await showTimePicker(
      context: context,
      initialTime: _digestTime,
    );
    if (selected != null) {
      setState(() {
        //2.- Persistimos la nueva configuración localmente dentro del estado temporal.
        _digestTime = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //1.- Componemos un formulario sencillo que simula preferencias administrativas.
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Configuración del panel',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ShadcnCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    //1.- Alternamos la recepción de notificaciones críticas para el panel.
                    setState(() => _notificationsEnabled = value);
                  },
                  title: const Text('Notificaciones críticas'),
                  subtitle: const Text(
                    'Recibe alertas en tiempo real cuando se detecten incidencias críticas.',
                  ),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  value: _autoAssignIncidents,
                  onChanged: (value) {
                    //1.- Controlamos si el sistema asigna automáticamente reportes a agentes.
                    setState(() => _autoAssignIncidents = value);
                  },
                  title: const Text('Asignación automática'),
                  subtitle: const Text(
                    'Distribuye incidentes entrantes entre los equipos disponibles.',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Hora del resumen diario'),
                  subtitle: Text('Programado a las ${_digestTime.format(context)}'),
                  onTap: () => _selectDigestTime(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ShadcnButton(
            label: 'Guardar cambios',
            icon: Icons.save,
            onPressed: () {
              //1.- Simulamos un guardado local para mostrar retroalimentación inmediata.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preferencias guardadas correctamente.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
