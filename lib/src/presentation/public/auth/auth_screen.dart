import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/session_controller.dart';
import '../../../domain/entities/auth_credentials.dart';
import '../../../domain/value_objects/social_provider.dart';
import '../../widgets/primary_button.dart';
import '../../../app/providers.dart';
import 'recover_password_controller.dart';
import 'recover_password_state.dart';
import 'registration_controller.dart';
import 'registration_state.dart';
import 'social_sign_in_controller.dart';
import 'social_sign_in_state.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  String _signInEmail = '';
  String _signInPassword = '';

  void _submitSignIn(SessionController controller) {
    //1.- Llamamos al controlador global para autenticar con las credenciales capturadas.
    controller.signIn(AuthCredentials(email: _signInEmail, password: _signInPassword));
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    //1.- Agrupamos cada flujo en una tarjeta consistente para mejorar la lectura.
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionControllerProvider);
    final sessionController = ref.read(sessionControllerProvider.notifier);
    final registrationState = ref.watch(registrationControllerProvider);
    final registrationController = ref.read(registrationControllerProvider.notifier);
    final recoverState = ref.watch(recoverPasswordControllerProvider);
    final recoverController = ref.read(recoverPasswordControllerProvider.notifier);
    final socialState = ref.watch(socialSignInControllerProvider);
    final socialController = ref.read(socialSignInControllerProvider.notifier);

    final signInLoading = sessionState.status == SessionStatus.initializing;

    return Scaffold(
      appBar: AppBar(title: const Text('Acceso administrativo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Iniciar sesión',
              children: [
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  onChanged: (value) {
                    //1.- Guardamos el correo para construir las credenciales al enviar.
                    setState(() => _signInEmail = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  onChanged: (value) {
                    //1.- Persistimos la contraseña en el estado local del widget.
                    setState(() => _signInPassword = value);
                  },
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: signInLoading ? 'Ingresando…' : 'Ingresar',
                  onPressed: signInLoading ? null : () => _submitSignIn(sessionController),
                ),
                if (sessionState.status == SessionStatus.error &&
                    sessionState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      sessionState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            _buildSection(
              title: 'Crear cuenta',
              children: [
                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  initialValue: registrationState.email,
                  onChanged: registrationController.updateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  initialValue: registrationState.password,
                  onChanged: registrationController.updatePassword,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: registrationState.isLoading ? 'Registrando…' : 'Registrarse',
                  onPressed:
                      registrationState.isLoading ? null : () => registrationController.submit(),
                ),
                if (registrationState.status == RegistrationStatus.success)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('¡Registro completado! Redirigiendo al panel…'),
                  )
                else if (registrationState.status == RegistrationStatus.error &&
                    registrationState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      registrationState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            _buildSection(
              title: 'Recuperar contraseña',
              children: [
                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  initialValue: recoverState.email,
                  onChanged: recoverController.updateEmail,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: recoverState.isLoading ? 'Enviando…' : 'Enviar instrucciones',
                  onPressed: recoverState.isLoading ? null : () => recoverController.submit(),
                ),
                if (recoverState.status == RecoverPasswordStatus.success)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Revisa tu bandeja para continuar con el restablecimiento.'),
                  )
                else if (recoverState.status == RecoverPasswordStatus.error &&
                    recoverState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      recoverState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            _buildSection(
              title: 'Acceder con redes sociales',
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: SocialProvider.values.map((provider) {
                    return PrimaryButton(
                      expands: false,
                      label: provider.displayName,
                      onPressed: socialState.isLoading
                          ? null
                          : () => socialController.signIn(provider),
                    );
                  }).toList(),
                ),
                if (socialState.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  )
                else if (socialState.status == SocialSignInStatus.success &&
                    socialState.lastProvider != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Sesión iniciada con ${socialState.lastProvider!.displayName}.',
                    ),
                  )
                else if (socialState.status == SocialSignInStatus.error &&
                    socialState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      socialState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
