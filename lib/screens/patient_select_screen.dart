import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class PatientSelectScreen extends StatefulWidget {
  /// Si es true, viene del botón en AppBar → puede volver atrás.
  final bool allowBack;
  /// Builder de la pantalla destino (solo cuando allowBack=false).
  final WidgetBuilder? homeBuilder;
  const PatientSelectScreen({super.key, this.allowBack = false, this.homeBuilder});

  @override
  State<PatientSelectScreen> createState() => _PatientSelectScreenState();
}

class _PatientSelectScreenState extends State<PatientSelectScreen> {
  List<String> _patients = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final storage = await StorageService.getInstance();
    final cached = storage.getCachedPatients();
    if (cached.isNotEmpty) {
      setState(() {
        _patients = cached;
        _loading = false;
      });
    }
    try {
      final remote = await SupabaseService().getPatients();
      await storage.cachePatientsLocally(remote);
      if (mounted) {
        setState(() {
          _patients = remote;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPatient(String name) async {
    final storage = await StorageService.getInstance();
    await storage.setCurrentPatient(name);
    if (!mounted) return;
    if (widget.allowBack) {
      Navigator.pop(context, name);
    } else if (widget.homeBuilder != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: widget.homeBuilder!),
      );
    }
  }

  Future<void> _addPatient() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar paciente'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre completo'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Agregar',
                style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseService().addPatient(name);
      await _loadPatients();
    } catch (_) {
      final storage = await StorageService.getInstance();
      final updated = [..._patients, name];
      await storage.cachePatientsLocally(updated);
      if (mounted) setState(() => _patients = updated);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.allowBack
          ? AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.navy, AppColors.teal],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              title: const Text('Cambiar paciente',
                  style: TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navy, AppColors.teal],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              children: [
                const Text('🏥', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  '¿Para quién es el registro?',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona el paciente cuya glucosa vas a ver o registrar',
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(.8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Lista de pacientes
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏥', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            const Text('No hay pacientes aún',
                                style: TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _addPatient,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar paciente'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _patients.length,
                        itemBuilder: (_, i) {
                          final name = _patients[i];
                          final initial =
                              name.isNotEmpty ? name[0].toUpperCase() : '?';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.navy.withOpacity(.1),
                                child: Text(initial,
                                    style: const TextStyle(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w700)),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppColors.muted),
                              onTap: () => _selectPatient(name),
                            ),
                          );
                        },
                      ),
          ),

          // Botón agregar
          if (_patients.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _addPatient,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add),
                    label: const Text('Agregar paciente'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
