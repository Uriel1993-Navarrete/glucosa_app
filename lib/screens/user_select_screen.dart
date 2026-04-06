import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class UserSelectScreen extends StatefulWidget {
  /// Si es true, viene del botón "Cambiar" → puede volver atrás.
  final bool allowBack;
  /// Builder de la pantalla destino tras seleccionar usuario (solo cuando allowBack=false).
  /// Se usa el context propio de UserSelectScreen para navegar → evita context obsoleto.
  final WidgetBuilder? homeBuilder;
  const UserSelectScreen({super.key, this.allowBack = false, this.homeBuilder});

  @override
  State<UserSelectScreen> createState() => _UserSelectScreenState();
}

class _UserSelectScreenState extends State<UserSelectScreen> {
  List<String> _members = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final storage = await StorageService.getInstance();
    // Mostrar caché de inmediato
    final cached = storage.getCachedMembers();
    if (cached.isNotEmpty) {
      setState(() {
        _members = cached;
        _loading = false;
      });
    }
    // Intentar actualizar desde Supabase
    try {
      final remote = await SupabaseService().getFamilyMembers();
      await storage.cacheMembersLocally(remote);
      if (mounted) {
        setState(() {
          _members = remote;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectMember(String name) async {
    final storage = await StorageService.getInstance();
    await storage.setCurrentUser(name);
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

  Future<void> _addMember() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar familiar'),
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
            child: const Text('Agregar', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseService().addFamilyMember(name);
      await _loadMembers();
    } catch (_) {
      // Sin conexión: agregar localmente
      final storage = await StorageService.getInstance();
      final updated = [..._members, name];
      await storage.cacheMembersLocally(updated);
      setState(() {
        _members = updated;
        _saving = false;
      });
    }
    setState(() => _saving = false);
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
              title: const Text('Cambiar usuario', style: TextStyle(color: Colors.white)),
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
                const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  '¿Quién eres?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona tu nombre para registrar las lecturas',
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(.8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Lista de familiares
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👤', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            const Text('No hay familiares aún', style: TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _addMember,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar familiar'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _members.length,
                        itemBuilder: (_, i) {
                          final name = _members[i];
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.tealLight,
                                child: Text(initial,
                                    style: const TextStyle(
                                        color: AppColors.teal, fontWeight: FontWeight.w700)),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                              onTap: () => _selectMember(name),
                            ),
                          );
                        },
                      ),
          ),

          // Botón agregar
          if (_members.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _addMember,
                    icon: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add),
                    label: const Text('Agregar familiar'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
