import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/message_panel.dart';
import '../../widgets/role_selector.dart';

/// Aparece quando a conta existe mas o perfil não foi salvo
/// (ex.: a internet caiu logo depois de criar a conta).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.auth, required this.user});

  final AuthService auth;
  final User user;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _name = TextEditingController(text: widget.user.displayName);
  UserRole? _role;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Digite seu nome.');
      return;
    }
    if (_role == null) {
      setState(() => _error = 'Escolha o tipo de conta: Idoso ou Cuidador.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.createProfile(
        user: widget.user,
        name: _name.text,
        role: _role!,
      );
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completar cadastro'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Conta: ${widget.user.email ?? ''}',
            style: const TextStyle(fontSize: 18, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const Text(
            'Esta conta é para:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          RoleSelector(
            value: _role,
            onChanged: (r) => setState(() => _role = r),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
              labelText: 'Nome',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            MessagePanel(message: _error!),
          ],
          const SizedBox(height: 24),
          BigButton(
            label: _busy ? 'Salvando...' : 'Salvar e continuar',
            icon: Icons.check,
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}
