import 'package:flutter/material.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //1.- Presentamos la información clave del perfil administrativo con acciones rápidas.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.person, size: 32),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mariana López',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Administradora general',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Contacto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('mariana.lopez@ciudad.gob'),
              subtitle: const Text('Correo institucional'),
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('+52 55 1234 5678'),
              subtitle: const Text('Teléfono de guardia'),
            ),
            const Divider(height: 32),
            Text(
              'Roles y permisos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Chip(
              label: const Text('Gestión de reportes'),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
            const SizedBox(height: 8),
            Chip(
              label: const Text('Configuración avanzada'),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                //1.- Simulamos el envío de una solicitud para actualizar los datos del perfil.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Se solicitó la actualización del perfil.'),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Actualizar perfil'),
            ),
          ],
        ),
      ),
    );
  }
}
