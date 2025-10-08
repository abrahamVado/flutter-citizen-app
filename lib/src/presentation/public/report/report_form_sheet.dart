import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/shadcn/components/shadcn_button.dart';
import '../../design/shadcn/components/shadcn_card.dart';
import '../../design/shadcn/components/shadcn_input.dart';
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: ShadcnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Detalles del incidente',
                  style: Theme.of(context).textTheme.titleLarge),
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
                borderRadius: BorderRadius.circular(16),
                decoration: const InputDecoration(labelText: 'Tipo de incidente'),
              ),
              const SizedBox(height: 12),
              ShadcnInput(
                initialValue: state.description,
                maxLines: 3,
                onChanged: controller.updateDescription,
                label: 'Descripción',
              ),
              const SizedBox(height: 12),
              ShadcnInput(
                initialValue: state.contactEmail,
                onChanged: controller.updateContactEmail,
                label: 'Correo de contacto',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              ShadcnInput(
                initialValue: state.contactPhone,
                onChanged: controller.updateContactPhone,
                label: 'Teléfono de contacto',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              ShadcnInput(
                initialValue: state.address,
                onChanged: controller.updateAddress,
                label: 'Dirección aproximada',
              ),
              const SizedBox(height: 16),
              if (state.errorMessage != null)
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 12),
              ShadcnButton(
                label: 'Enviar reporte',
                loading: state.status == ReportFormStatus.loading,
                onPressed:
                    state.status == ReportFormStatus.loading ? null : controller.submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
