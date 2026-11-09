import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/message_panel.dart';
import 'register_screen.dart';

/// Login por e-mail e senha.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.signIn(email: _email.text, password: _password.text);
      // O AuthGate troca de tela sozinho ao detectar o login.
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(
        () => _error = 'Digite seu e-mail acima para redefinir a senha.',
      );
      return;
    }
    try {
      await widget.auth.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enviamos um link de nova senha para $email')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anjo da Guarda')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.shield, size: 72, color: Color(0xFF2E7D8C)),
              const SizedBox(height: 8),
              const Text(
                'Entrar na sua conta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Digite um e-mail válido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Mostrar senha' : 'Esconder senha',
                    icon: Icon(
                      _hidePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Digite sua senha' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                MessagePanel(message: _error!),
              ],
              const SizedBox(height: 24),
              BigButton(
                label: _busy ? 'Entrando...' : 'Entrar',
                icon: Icons.login,
                onPressed: _busy ? null : _signIn,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _resetPassword,
                child: const Text(
                  'Esqueci minha senha',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const Divider(height: 32),
              BigButton(
                label: 'Criar conta',
                icon: Icons.person_add,
                outlined: true,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RegisterScreen(auth: widget.auth),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
