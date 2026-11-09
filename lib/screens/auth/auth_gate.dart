import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/message_panel.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

/// Decide a tela inicial: login, completar cadastro,
/// interface do idoso ou interface do cuidador.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.elderBuilder,
    required this.caregiverBuilder,
  });

  final AuthService auth;
  final Widget Function(UserProfile profile) elderBuilder;
  final Widget Function(UserProfile profile) caregiverBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authChanges(),
      initialData: auth.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return LoginScreen(auth: auth);
        return _ProfileGate(
          key: ValueKey(user.uid),
          auth: auth,
          user: user,
          elderBuilder: elderBuilder,
          caregiverBuilder: caregiverBuilder,
        );
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({
    super.key,
    required this.auth,
    required this.user,
    required this.elderBuilder,
    required this.caregiverBuilder,
  });

  final AuthService auth;
  final User user;
  final Widget Function(UserProfile profile) elderBuilder;
  final Widget Function(UserProfile profile) caregiverBuilder;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  DocumentSnapshot<Map<String, dynamic>>? _snapshot;
  Object? _error;

  /// O perfil só muda de tipo ao trocar de conta; guardamos o último
  /// para não recriar a interface a cada atualização do documento.
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    setState(() => _error = null);
    _sub = widget.auth
        .profileSnapshots(widget.user.uid)
        .listen(
          (snap) => setState(() {
            _snapshot = snap;
            final profile = UserProfile.fromDoc(snap);
            if (profile != null) _profile = profile;
          }),
          onError: (Object e) => setState(() => _error = e),
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile != null) {
      return KeyedSubtree(
        key: ValueKey('${profile.uid}-${profile.role.id}'),
        child: profile.isElder
            ? widget.elderBuilder(profile)
            : widget.caregiverBuilder(profile),
      );
    }
    if (_error != null) {
      return _GateMessage(
        message:
            'Não foi possível carregar seu perfil. ${authErrorMessage(_error!)}',
        onRetry: _listen,
        onSignOut: widget.auth.signOut,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: widget.auth.registering,
      builder: (context, registering, _) {
        final snap = _snapshot;
        // Ainda carregando, criando a conta, ou só com o cache local
        // (sem confirmação do servidor de que o perfil não existe).
        if (registering ||
            snap == null ||
            (!snap.exists && snap.metadata.isFromCache)) {
          return const _Loading();
        }
        return ProfileSetupScreen(auth: widget.auth, user: widget.user);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando sua conta...', style: TextStyle(fontSize: 19)),
          ],
        ),
      ),
    );
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anjo da Guarda')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MessagePanel(message: message),
          const SizedBox(height: 16),
          BigButton(
            label: 'Tentar de novo',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
          const SizedBox(height: 12),
          BigButton(
            label: 'Sair da conta',
            icon: Icons.logout,
            outlined: true,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}
