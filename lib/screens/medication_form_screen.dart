import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/medication_controller.dart';
import '../services/photo_service.dart';
import '../widgets/big_button.dart';

/// Depois da foto: mostra a imagem, pede nome e horário e agenda o lembrete.
class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({
    super.key,
    required this.controller,
    required this.photos,
    required this.initialPhotoPath,
  });

  final MedicationController controller;
  final PhotoService photos;
  final String initialPhotoPath;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late String _photoPath = widget.initialPhotoPath;
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _retakePhoto() async {
    try {
      final path = await widget.photos.takePhoto();
      if (path != null) setState(() => _photoPath = path);
    } on PhotoException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      helpText: 'Horário do remédio',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_time == null) {
      _showMessage('Escolha o horário do remédio.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.add(
        name: _name.text.trim(),
        hour: _time!.hour,
        minute: _time!.minute,
        tempPhotoPath: _photoPath,
      );
      if (!mounted) return;
      _showMessage('Lembrete agendado para ${_time!.format(context)}.');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Erro ao salvar: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo remédio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(_photoPath),
                height: 280,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            BigButton(
              label: 'Tirar outra foto',
              icon: Icons.camera_alt,
              outlined: true,
              onPressed: _saving ? null : _retakePhoto,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              style: const TextStyle(fontSize: 22),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome do remédio',
                prefixIcon: Icon(Icons.medication),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Digite o nome do remédio'
                  : null,
            ),
            const SizedBox(height: 16),
            BigButton(
              label: _time == null
                  ? 'Escolher horário'
                  : 'Horário: ${_time!.format(context)}',
              icon: Icons.access_time,
              outlined: true,
              onPressed: _saving ? null : _pickTime,
            ),
            const SizedBox(height: 32),
            BigButton(
              label: _saving ? 'Salvando...' : 'Salvar e agendar lembrete',
              icon: Icons.check_circle,
              height: 72,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
