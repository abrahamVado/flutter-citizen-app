import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expands = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expands;

  @override
  Widget build(BuildContext context) {
    //1.- Construimos un botón elevado con la paleta principal de la aplicación.
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(label),
      ),
    );
    if (!expands) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
