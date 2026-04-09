import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reading.dart';
import '../models/oxygen_reading.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class DataScreen extends StatefulWidget {
  final List<Reading> readings;
  final List<OxygenReading> oxygenReadings;
  final VoidCallback onChanged;
  final String currentPatient;
  const DataScreen({
    super.key,
    required this.readings,
    required this.oxygenReadings,
    required this.onChanged,
    required this.currentPatient,
  });

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _syncing = false;

  Future<void> _shareCSV(BuildContext context) async {
    if (widget.readings.isEmpty) {
      _snack(context, 'No hay datos de glucosa que exportar');
      return;
    }
    try {
      final storage = await StorageService.getInstance();
      final path = await storage.exportCsvPath(widget.readings);
      await Share.shareXFiles([XFile(path)],
          text: 'Historial de glucosa (Excel/CSV)',
          subject: 'Historial glucosa CSV');
    } catch (e) {
      _snack(context, 'Error: $e');
    }
  }

  Future<void> _shareOxygenCSV(BuildContext context) async {
    if (widget.oxygenReadings.isEmpty) {
      _snack(context, 'No hay datos de oxigenación que exportar');
      return;
    }
    try {
      final storage = await StorageService.getInstance();
      final path = await storage.exportOxygenCsvPath(widget.oxygenReadings);
      await Share.shareXFiles([XFile(path)],
          text: 'Historial de saturación de oxígeno (Excel/CSV)',
          subject: 'Historial SpO2 CSV');
    } catch (e) {
      _snack(context, 'Error: $e');
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    setState(() => _syncing = true);
    try {
      final storage = await StorageService.getInstance();
      // Glucosa
      await SupabaseService().syncToRemote(widget.readings);
      final mergedGlucose = await SupabaseService().fetchAndMerge(widget.readings);
      await storage.saveReadings(mergedGlucose);
      // Oxigenación
      await SupabaseService().syncOxygenToRemote(widget.oxygenReadings);
      final mergedOxygen = await SupabaseService().fetchAndMergeOxygen(widget.oxygenReadings);
      await storage.saveOxygenReadings(mergedOxygen);
      await storage.markSyncNow();
      widget.onChanged();
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
        content: const Text(
            'Esta acción eliminará todos los registros (glucosa y oxigenación) permanentemente. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo',
                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final storage = await StorageService.getInstance();
    await storage.clearAll();
    widget.onChanged();
    if (mounted) _snack(context, 'Historial eliminado');
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.teal, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Los datos se guardan automáticamente y se sincronizan con la nube.',
                style: TextStyle(fontSize: 12, color: AppColors.teal, height: 1.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('🩸 ${widget.readings.length} glucosa',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.teal, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('🫁 ${widget.oxygenReadings.length} O₂',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.teal, fontSize: 12)),
                ],
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
          icon: '📊',
          title: 'Exportar glucosa para el médico',
          desc: 'CSV compatible con Excel — ${widget.readings.length} registros',
          color: AppColors.amber,
          onTap: () => _shareCSV(context),
        ),
        _actionCard(
          context,
          icon: '🫁',
          title: 'Exportar oxigenación para el médico',
          desc: 'CSV compatible con Excel — ${widget.oxygenReadings.length} registros',
          color: AppColors.oxygenNormal,
          onTap: () => _shareOxygenCSV(context),
        ),
        const SizedBox(height: 8),
        _actionCard(
          context,
          icon: '🗑️',
          title: 'Borrar todos los datos',
          desc: 'Elimina glucosa y oxigenación. No se puede deshacer.',
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
          side: border ? const BorderSide(color: AppColors.redBg, width: 1.5) : BorderSide.none,
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
                      Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      );
}
