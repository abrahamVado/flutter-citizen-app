import 'package:flutter/material.dart';

class ShadcnInput extends StatelessWidget {
  const ShadcnInput({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.label,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.hintText,
  }) : assert(controller == null || initialValue == null,
            'No se puede usar initialValue y controller al mismo tiempo');

  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final String? label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    //1.- Delegamos en TextFormField pero aplicando la decoración coherente con el tema shadcn.
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}
