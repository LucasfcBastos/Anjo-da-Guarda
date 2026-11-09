import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/message_panel.dart';
import '../../widgets/role_selector.dart';

/// Cadastro: nome, e-mail, senha e tipo de conta (idoso ou cuidador).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole? _role;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final valid = _formKey.currentState!.validate();
    if (_role == null) {
      setState(() => _error = 'Escolha o tipo de conta: Idoso ou Cuidador.');
      return;
    }
    if (!valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        role: _role!,
      );
      // Logado: volta para a raiz, onde o AuthGate abre a tela certa.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Esta conta é para:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              RoleSelector(
                value: _role,
                onChanged: (r) => setState(() {
                  _role = r;
                  _error = null;
                }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                maxLength: 80,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Digite seu nome'
                    : null,
              ),
              const SizedBox(height: 8),
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
                validator: (v) {
                  final t = v?.trim() ?? '';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                      ? null
                      : 'Digite um e-mail válido';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Senha (mínimo 6 caracteres)',
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
                validator: (v) => (v == null || v.length < 6)
                    ? 'A senha precisa de pelo menos 6 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'Repita a senha',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    v != _password.text ? 'As senhas não são iguais' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                MessagePanel(message: _error!),
              ],
              const SizedBox(height: 24),
              BigButton(
                label: _busy ? 'Criando conta...' : 'Criar conta',
                icon: Icons.check,
                onPressed: _busy ? null : _register,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
