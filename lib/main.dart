import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/reading.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'screens/register_screen.dart';
import 'screens/history_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/data_screen.dart';
import 'screens/user_select_screen.dart';
import 'screens/patient_select_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await SupabaseService.initialize();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.navy,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const GlucosaApp());
}

class GlucosaApp extends StatelessWidget {
  const GlucosaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Glucosa',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashRouter(),
    );
  }
}

/// Decide la primera pantalla según si hay usuario y paciente guardados.
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final storage = await StorageService.getInstance();
    final user = storage.getCurrentUser();
    final patient = storage.getCurrentPatient();
    if (!mounted) return;

    if (user == null || user.isEmpty) {
      // Sin usuario → seleccionar usuario primero
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserSelectScreen(
            homeBuilder: (_) => const SplashRouter(),
          ),
        ),
      );
    } else if (patient == null || patient.isEmpty) {
      // Sin paciente → seleccionar paciente
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PatientSelectScreen(
            homeBuilder: (_) => const HomeScreen(),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  List<Reading> _allReadings = [];
  bool _loaded = false;
  String _currentUser = '';
  String _currentPatient = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;

  List<Reading> get _patientReadings =>
      _allReadings.where((r) => r.patientName == _currentPatient).toList();

  @override
  void initState() {
    super.initState();
    _loadReadings();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _wasOffline && _loaded) {
        _triggerSync();
      }
      _wasOffline = !isOnline;
    });
  }

  Future<void> _triggerSync() async {
    final storage = await StorageService.getInstance();
    await _syncBackground(storage, _allReadings);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadReadings() async {
    final storage = await StorageService.getInstance();
    final user = storage.getCurrentUser() ?? '';
    final patient = storage.getCurrentPatient() ?? '';
    final local = storage.loadReadings();
    local.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _currentUser = user;
      _currentPatient = patient;
      _allReadings = local;
      _loaded = true;
    });
    _syncBackground(storage, local);
  }

  Future<void> _syncBackground(StorageService storage, List<Reading> local) async {
    try {
      if (!storage.initialSyncDone) {
        await SupabaseService().syncToRemote(local);
        await storage.markInitialSyncDone();
      }
      final merged = await SupabaseService().fetchAndMerge(local);
      await storage.saveReadings(merged);
      await storage.markSyncNow();
      if (mounted) {
        setState(() => _allReadings = merged);
      }
    } catch (e) {
      debugPrint('[Sync] Error: $e');
    }
  }

  Future<void> _refresh() async {
    final storage = await StorageService.getInstance();
    final all = storage.loadReadings();
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() => _allReadings = all);
  }

  Future<void> _changeUser() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const UserSelectScreen(allowBack: true),
      ),
    );
    if (result != null && mounted) setState(() => _currentUser = result);
  }

  Future<void> _changePatient() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const PatientSelectScreen(allowBack: true),
      ),
    );
    if (result != null && mounted) setState(() => _currentPatient = result);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final patientReadings = _patientReadings;

    final tabs = [
      _TabItem(label: 'Registrar', icon: Icons.edit_outlined, activeIcon: Icons.edit),
      _TabItem(label: 'Historial', icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt),
      _TabItem(label: 'Gráfica', icon: Icons.show_chart_outlined, activeIcon: Icons.show_chart),
      _TabItem(label: 'Datos', icon: Icons.cloud_outlined, activeIcon: Icons.cloud),
    ];

    final pages = [
      RegisterScreen(
        readings: patientReadings,
        onSaved: _refresh,
        currentUser: _currentUser,
        currentPatient: _currentPatient,
      ),
      HistoryScreen(readings: patientReadings, onChanged: _refresh),
      ChartScreen(readings: patientReadings),
      DataScreen(
        readings: patientReadings,
        onChanged: _refresh,
        currentPatient: _currentPatient,
      ),
    ];

    final shortUser = _currentUser.split(' ').first;
    final shortPatient = _currentPatient.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.teal],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: Row(
          children: [
            const Text('🩸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Control de Glucosa',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('${patientReadings.length} registros · $shortPatient',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(.75))),
              ],
            ),
          ],
        ),
        actions: [
          // Selector de usuario (quien registra)
          InkWell(
            onTap: _changeUser,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 3),
                  Text(shortUser,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Selector de paciente
          InkWell(
            onTap: _changePatient,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.medical_information_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 3),
                  Text(shortPatient,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: tabs
            .asMap()
            .entries
            .map((e) => BottomNavigationBarItem(
                  icon: Icon(_tabIndex == e.key ? e.value.activeIcon : e.value.icon),
                  label: e.value.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem({required this.label, required this.icon, required this.activeIcon});
}
