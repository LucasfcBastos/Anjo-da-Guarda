import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/medication_controller.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';
import '../widgets/big_button.dart';
import '../widgets/message_panel.dart';
import 'medication_form_screen.dart';

/// Lista de remédios cadastrados e botão para fotografar um novo.
class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({
    super.key,
    required this.controller,
    required this.notifications,
  });

  final MedicationController controller;
  final NotificationService notifications;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _photos = PhotoService();
  bool _exactAlarms = true;

  @override
  void initState() {
    super.initState();
    _checkExactAlarms();
    _recoverLostPhoto();
  }

  Future<void> _checkExactAlarms() async {
    final ok = await widget.notifications.canScheduleExactAlarms();
    if (mounted) setState(() => _exactAlarms = ok);
  }

  /// Se o Android fechou o app enquanto a câmera estava aberta,
  /// retoma o cadastro com a foto que foi tirada.
  Future<void> _recoverLostPhoto() async {
    final path = await _photos.recoverLostPhoto();
    if (path != null && mounted) _openForm(path);
  }

  Future<void> _takePhoto() async {
    try {
      final path = await _photos.takePhoto();
      if (path != null && mounted) _openForm(path);
    } on PhotoException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _openForm(String photoPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          controller: widget.controller,
          photos: _photos,
          initialPhotoPath: photoPath,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${med.name}?'),
        content: const Text('O lembrete deste remédio será cancelado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.controller.remove(med);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicamentos')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final meds = widget.controller.items;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BigButton(
                label: 'Fotografar remédio',
                icon: Icons.photo_camera,
                height: 76,
                onPressed: _takePhoto,
              ),
              if (!_exactAlarms) ...[
                const SizedBox(height: 16),
                MessagePanel(
                  message:
                      'Para o lembrete tocar no minuto exato, permita '
                      '"Alarmes e lembretes" para o app.',
                  actionLabel: 'Permitir alarmes',
                  onAction: () async {
                    await widget.notifications.requestExactAlarmsPermission();
                    await _checkExactAlarms();
                  },
                ),
              ],
              const SizedBox(height: 24),
              if (widget.controller.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (meds.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhum remédio cadastrado.\n'
                    'Toque em "Fotografar remédio" para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, color: Colors.black54),
                  ),
                )
              else
                for (final med in meds) ...[
                  _MedicationTile(
                    med: med,
                    onDelete: () => _confirmDelete(med),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.med, required this.onDelete});

  final Medication med;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Image.file(
            File(med.photoPath),
            width: 110,
            height: 110,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 110,
              height: 110,
              child: Icon(Icons.broken_image, size: 48),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.alarm, size: 24),
                    const SizedBox(width: 6),
                    Text(
                      'Todo dia às ${med.timeLabel}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            iconSize: 32,
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
