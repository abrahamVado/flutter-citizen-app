import 'package:flutter/material.dart';

enum ShadcnButtonVariant { primary, outline, ghost }

class ShadcnButton extends StatelessWidget {
  const ShadcnButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ShadcnButtonVariant.primary,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ShadcnButtonVariant variant;
  final bool expand;
  final bool loading;

  ButtonStyle _primaryStyle(BuildContext context) {
    //1.- Reutilizamos la configuración del tema pero añadimos elevación suave.
    return FilledButton.styleFrom(
      elevation: 0,
      shadowColor: Colors.transparent,
    );
  }

  ButtonStyle _outlineStyle(BuildContext context) {
    //1.- Generamos un estilo con borde visible y fondo transparente.
    return OutlinedButton.styleFrom(
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    );
  }

  ButtonStyle _ghostStyle(BuildContext context) {
    //1.- Mostramos un botón plano con relleno reducido para acciones secundarias.
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildContent() {
    //1.- Colocamos un indicador de carga opcional seguido del texto e ícono.
    final children = <Widget>[];
    if (loading) {
      children.add(const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    } else if (icon != null) {
      children.add(Icon(icon, size: 18));
    }
    children.add(Flexible(
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
    ));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          children[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    //1.- Seleccionamos el estilo según la variante y creamos el botón adecuado.
    final button = switch (variant) {
      ShadcnButtonVariant.primary => FilledButton(
          onPressed: loading ? null : onPressed,
          style: _primaryStyle(context),
          child: _buildContent(),
        ),
      ShadcnButtonVariant.outline => OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: _outlineStyle(context),
          child: _buildContent(),
        ),
      ShadcnButtonVariant.ghost => TextButton(
          onPressed: loading ? null : onPressed,
          style: _ghostStyle(context),
          child: _buildContent(),
        ),
    };
    if (!expand) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
