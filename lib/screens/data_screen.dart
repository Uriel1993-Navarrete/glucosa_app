import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reading.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class DataScreen extends StatefulWidget {
  final List<Reading> readings;
  final VoidCallback onChanged;
  final String currentPatient;
  const DataScreen({
    super.key,
    required this.readings,
    required this.onChanged,
    required this.currentPatient,
  });

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  List<Reading> get readings => widget.readings;
  VoidCallback get onChanged => widget.onChanged;
  bool _syncing = false;

  Future<void> _share(BuildContext context) async {
    if (readings.isEmpty) {
      _snack(context, 'No hay datos que exportar');
      return;
    }
    try {
      final storage = await StorageService.getInstance();
      final path = await storage.exportJsonPath(readings);
      await Share.shareXFiles([XFile(path)],
          text: 'Historial de glucosa — Control de Glucosa App',
          subject: 'Historial glucosa');
    } catch (e) {
      _snack(context, 'Error al exportar: $e');
    }
  }

  Future<void> _shareCSV(BuildContext context) async {
    if (readings.isEmpty) {
      _snack(context, 'No hay datos que exportar');
      return;
    }
    try {
      final storage = await StorageService.getInstance();
      final path = await storage.exportCsvPath(readings);
      await Share.shareXFiles([XFile(path)],
          text: 'Historial de glucosa (Excel/CSV)',
          subject: 'Historial glucosa CSV');
    } catch (e) {
      _snack(context, 'Error: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('¿Cargar este historial?'),
          content: const Text(
              'Esto reemplazará los datos actuales en este dispositivo. Los datos también quedarán guardados automáticamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cargar', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      final storage = await StorageService.getInstance();
      await storage.importFromJsonString(content);
      onChanged();
      _snack(context, '✓ Historial cargado y guardado correctamente');
    } catch (e) {
      _snack(context, '❌ Archivo inválido o error al cargar');
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final storage = await StorageService.getInstance();
      // Subir primero los locales que faltan en Supabase
      await SupabaseService().syncToRemote(readings);
      // Luego descargar y hacer merge
      final merged = await SupabaseService().fetchAndMerge(readings);
      await storage.saveReadings(merged);
      await storage.markSyncNow();
      onChanged();
      if (mounted) _snack(context, '✓ Sincronizado con la nube');
    } catch (e) {
      debugPrint('[SyncNow] Error: $e');
      if (mounted) _snack(context, '❌ Sin conexión. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _reset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Borrar todo el historial?'),
        content: const Text('Esta acción eliminará todos los registros permanentemente. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final storage = await StorageService.getInstance();
    await storage.clearAll();
    onChanged();
    _snack(context, 'Historial eliminado');
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(12),
            border: const Border(left: BorderSide(color: AppColors.teal, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💾 Paciente: ${widget.currentPatient}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                'Los datos se guardan automáticamente y se sincronizan con la nube. '
                'Usa "Sincronizar" para ver los registros de otros familiares.',
                style: TextStyle(fontSize: 12, color: AppColors.teal.withOpacity(.85), height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '📊 ${readings.length} registros de ${widget.currentPatient.split(' ').first}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _actionCard(
          context,
          icon: '🔄',
          title: 'Sincronizar con la nube',
          desc: 'Descarga registros de otros familiares y sube los tuyos',
          color: AppColors.teal,
          loading: _syncing,
          onTap: _syncing ? () {} : () => _syncNow(context),
        ),
        _actionCard(
          context,
          icon: '📤',
          title: 'Compartir con la familia',
          desc: 'Manda el historial por WhatsApp, correo, etc.',
          color: AppColors.teal,
          onTap: () => _share(context),
        ),
        _actionCard(
          context,
          icon: '📥',
          title: 'Cargar historial',
          desc: 'Importa el archivo de otro familiar — queda guardado automáticamente',
          color: AppColors.navy,
          onTap: () => _import(context),
        ),
        _actionCard(
          context,
          icon: '📊',
          title: 'Exportar para el médico (CSV)',
          desc: 'Formato que abre en Excel para imprimir o revisar',
          color: AppColors.amber,
          onTap: () => _shareCSV(context),
        ),
        const SizedBox(height: 8),
        _actionCard(
          context,
          icon: '🗑️',
          title: 'Borrar todos los datos',
          desc: 'Elimina el historial completo. No se puede deshacer.',
          color: AppColors.red,
          border: true,
          onTap: () => _reset(context),
        ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
    bool border = false,
    bool loading = false,
  }) =>
      Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: border ? BorderSide(color: AppColors.redBg, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: border ? color : AppColors.navy)),
                      const SizedBox(height: 2),
                      Text(desc,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      );
}
