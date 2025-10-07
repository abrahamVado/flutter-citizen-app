import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report_form_controller.dart';
import 'report_form_state.dart';

class ReportFormSheet extends ConsumerWidget {
  const ReportFormSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Escuchamos el estado del formulario para reaccionar a envíos y errores.
    final state = ref.watch(reportFormControllerProvider);
    final controller = ref.watch(reportFormControllerProvider.notifier);
    ref.listen(reportFormControllerProvider, (previous, next) {
      //2.- Cerramos el sheet cuando un envío es exitoso, mostrando un mensaje de confirmación.
      if (previous?.status != ReportFormStatus.success &&
          next.status == ReportFormStatus.success &&
          next.submittedReport != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reporte enviado con folio ${next.submittedReport!.id}')),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalles del incidente', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: state.selectedTypeId,
              items: state.types
                  .map((type) => DropdownMenuItem(
                        value: type.id,
                        child: Text(type.name),
                      ))
                  .toList(),
              onChanged: controller.selectIncidentType,
              decoration: const InputDecoration(labelText: 'Tipo de incidente'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.description,
              maxLines: 3,
              onChanged: controller.updateDescription,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.contactEmail,
              onChanged: controller.updateContactEmail,
              decoration: const InputDecoration(labelText: 'Correo de contacto'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.contactPhone,
              onChanged: controller.updateContactPhone,
              decoration: const InputDecoration(labelText: 'Teléfono de contacto'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.address,
              onChanged: controller.updateAddress,
              decoration: const InputDecoration(labelText: 'Dirección aproximada'),
            ),
            const SizedBox(height: 16),
            if (state.errorMessage != null)
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.status == ReportFormStatus.loading
                    ? null
                    : () => controller.submit(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: state.status == ReportFormStatus.loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar reporte'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
