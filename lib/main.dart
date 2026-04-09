import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/reading.dart';
import 'models/oxygen_reading.dart';
import 'models/blood_pressure_reading.dart';
import 'models/heart_rate_reading.dart';
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
  List<OxygenReading> _allOxygenReadings = [];
  List<BloodPressureReading> _allBPReadings = [];
  List<HeartRateReading> _allHRReadings = [];
  bool _loaded = false;
  String _currentUser = '';
  String _currentPatient = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;

  List<Reading> get _patientReadings =>
      _allReadings.where((r) => r.patientName == _currentPatient).toList();

  List<OxygenReading> get _patientOxygenReadings =>
      _allOxygenReadings.where((r) => r.patientName == _currentPatient).toList();

  List<BloodPressureReading> get _patientBPReadings =>
      _allBPReadings.where((r) => r.patientName == _currentPatient).toList();

  List<HeartRateReading> get _patientHRReadings =>
      _allHRReadings.where((r) => r.patientName == _currentPatient).toList();

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
    final localOxygen = storage.loadOxygenReadings();
    localOxygen.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final localBP = storage.loadBPReadings();
    localBP.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final localHR = storage.loadHRReadings();
    localHR.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _currentUser = user;
      _currentPatient = patient;
      _allReadings = local;
      _allOxygenReadings = localOxygen;
      _allBPReadings = localBP;
      _allHRReadings = localHR;
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
      // Sync oxygen
      final localOxygen = storage.loadOxygenReadings();
      await SupabaseService().syncOxygenToRemote(localOxygen);
      final mergedOxygen = await SupabaseService().fetchAndMergeOxygen(localOxygen);
      await storage.saveOxygenReadings(mergedOxygen);
      // Sync presión arterial
      final localBP = storage.loadBPReadings();
      await SupabaseService().syncBPToRemote(localBP);
      final mergedBP = await SupabaseService().fetchAndMergeBP(localBP);
      await storage.saveBPReadings(mergedBP);
      // Sync pulso
      final localHR = storage.loadHRReadings();
      await SupabaseService().syncHRToRemote(localHR);
      final mergedHR = await SupabaseService().fetchAndMergeHR(localHR);
      await storage.saveHRReadings(mergedHR);
      if (mounted) {
        setState(() {
          _allReadings = merged;
          _allOxygenReadings = mergedOxygen;
          _allBPReadings = mergedBP;
          _allHRReadings = mergedHR;
        });
      }
    } catch (e) {
      debugPrint('[Sync] Error: $e');
    }
  }

  Future<void> _refresh() async {
    final storage = await StorageService.getInstance();
    final all = storage.loadReadings();
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final allOxygen = storage.loadOxygenReadings();
    allOxygen.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final allBP = storage.loadBPReadings();
    allBP.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final allHR = storage.loadHRReadings();
    allHR.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _allReadings = all;
      _allOxygenReadings = allOxygen;
      _allBPReadings = allBP;
      _allHRReadings = allHR;
    });
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
      const _TabItem(label: 'Registrar', icon: Icons.edit_outlined, activeIcon: Icons.edit),
      const _TabItem(label: 'Historial', icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt),
      const _TabItem(label: 'Gráfica', icon: Icons.show_chart_outlined, activeIcon: Icons.show_chart),
      const _TabItem(label: 'Datos', icon: Icons.cloud_outlined, activeIcon: Icons.cloud),
    ];

    final oxygenReadings = _patientOxygenReadings;
    final bpReadings = _patientBPReadings;
    final hrReadings = _patientHRReadings;

    final pages = [
      RegisterScreen(
        readings: patientReadings,
        oxygenReadings: oxygenReadings,
        bpReadings: bpReadings,
        hrReadings: hrReadings,
        onSaved: _refresh,
        currentUser: _currentUser,
        currentPatient: _currentPatient,
      ),
      HistoryScreen(
        readings: patientReadings,
        oxygenReadings: oxygenReadings,
        bpReadings: bpReadings,
        hrReadings: hrReadings,
        onChanged: _refresh,
      ),
      ChartScreen(
        readings: patientReadings,
        oxygenReadings: oxygenReadings,
        bpReadings: bpReadings,
        hrReadings: hrReadings,
      ),
      DataScreen(
        readings: patientReadings,
        oxygenReadings: oxygenReadings,
        bpReadings: bpReadings,
        hrReadings: hrReadings,
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
