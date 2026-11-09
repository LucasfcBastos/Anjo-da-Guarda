import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/caregiver_controller.dart';
import '../../services/auth_service.dart';
import '../../services/link_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/message_panel.dart';

/// O cuidador digita o código gerado no celular do idoso.
class LinkElderScreen extends StatefulWidget {
  const LinkElderScreen({super.key, required this.controller});

  final CaregiverController controller;

  @override
  State<LinkElderScreen> createState() => _LinkElderScreenState();
}

class _LinkElderScreenState extends State<LinkElderScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await widget.controller.requestLink(_code.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido enviado! Agora $name precisa autorizar no celular dele.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is LinkException ? e.message : authErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular idoso')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '1. No celular do idoso, abra a aba "Família" e toque em '
            '"Gerar código".\n'
            '2. Digite o código abaixo.\n'
            '3. O idoso autoriza o pedido no celular dele.',
            style: TextStyle(fontSize: 18, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
            ],
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
            decoration: const InputDecoration(
              labelText: 'Código de 6 caracteres',
              hintText: 'ABC 234',
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            MessagePanel(message: _error!),
          ],
          const SizedBox(height: 16),
          BigButton(
            label: _busy ? 'Enviando...' : 'Enviar pedido',
            icon: Icons.link,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
