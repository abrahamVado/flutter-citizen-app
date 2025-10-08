import 'package:flutter/material.dart';

class ShadcnCard extends StatelessWidget {
  const ShadcnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    //1.- Combinamos fondo claro, borde suave y sombra difusa para emular las tarjetas de shadcn.
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 10),
            blurRadius: 30,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: DefaultTextStyle.merge(
          style: theme.textTheme.bodyMedium,
          child: child,
        ),
      ),
    );
  }
}
