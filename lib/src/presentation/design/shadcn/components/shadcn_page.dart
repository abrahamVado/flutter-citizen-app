import 'package:flutter/material.dart';

class ShadcnPage extends StatelessWidget {
  const ShadcnPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.scrollable = false,
    this.background,
    this.bottomBar,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final Color? background;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    //1.- Renderizamos un Scaffold con AppBar claro y contenedor acolchado, emulando el layout base de shadcn/ui.
    final content = Padding(
      padding: padding,
      child: child,
    );
    final safeContent = scrollable
        ? SingleChildScrollView(child: content)
        : content;
    return Scaffold(
      backgroundColor: background ?? Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(child: safeContent),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
