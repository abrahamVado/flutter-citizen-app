import 'package:flutter/material.dart';

import '../../design/shadcn/components/shadcn_button.dart';
import '../../design/shadcn/components/shadcn_card.dart';

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
            ShadcnCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    child: Icon(Icons.person,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary),
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
            ),
            const SizedBox(height: 24),
            Text(
              'Contacto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ShadcnCard(
              child: Column(
                children: const [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.email_outlined),
                    title: Text('mariana.lopez@ciudad.gob'),
                    subtitle: Text('Correo institucional'),
                  ),
                  Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.call_outlined),
                    title: Text('+52 55 1234 5678'),
                    subtitle: Text('Teléfono de guardia'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Roles y permisos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Chip(
                  label: const Text('Gestión de reportes'),
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                ),
                Chip(
                  label: const Text('Configuración avanzada'),
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                ),
              ],
            ),
            const Spacer(),
            ShadcnButton(
              label: 'Actualizar perfil',
              icon: Icons.edit_outlined,
              onPressed: () {
                //1.- Simulamos el envío de una solicitud para actualizar los datos del perfil.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Se solicitó la actualización del perfil.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
