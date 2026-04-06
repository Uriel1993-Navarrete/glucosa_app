# Plan: Migración a Supabase — glucosa_app

## Contexto

La app actualmente guarda todo en SharedPreferences (local). Se necesita:
- Base de datos compartida en Supabase para que toda la familia vea los mismos datos
- Login por nombre (sin contraseña): se selecciona de una lista de familiares, se guarda la sesión
- Cada registro incluye quién lo creó (`recorded_by`)
- Soporte offline: funciona sin internet, sincroniza automáticamente al conectarse
- Migración automática de datos locales existentes a Supabase

**Respuestas del usuario:**
- Login: se pide una vez, queda guardado. Opción de cambiar usuario desde la AppBar
- Offline: sí, offline + sync automático
- Datos actuales: migrar a Supabase en la primera sincronización
- Usuarios: lista de familiares guardados en Supabase, se pueden agregar nuevos

> ⚠️ **Nota MCP:** El MCP de Supabase fue agregado a la configuración (`claude.json`). Requiere reiniciar Claude Code para activarse. El **Paso 1** (crear schema en DB) se ejecutará con MCP una vez disponible.

---

## Credenciales Supabase (proyecto glucosa-app, ID: kfbfnfrwhmdoeqxyikdb)

```
URL: https://kfbfnfrwhmdoeqxyikdb.supabase.co
Anon Key: sb_publishable_bOEn7FRnO_P9WyMSID4sqA_d0MHLQF5
```

---

## Paso 1 — Crear schema en Supabase (vía MCP)

Aplicar esta migración con `mcp__supabase__apply_migration`:

```sql
-- Familiares que pueden registrar lecturas
CREATE TABLE IF NOT EXISTS family_members (
  id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lecturas de glucosa
CREATE TABLE IF NOT EXISTS readings (
  id            TEXT PRIMARY KEY,
  recorded_by   TEXT NOT NULL DEFAULT 'Sin nombre',
  recorded_at   TIMESTAMPTZ NOT NULL,
  glucose_value INTEGER NOT NULL,
  moment        TEXT NOT NULL,
  insulin_dose  INTEGER,
  insulin_type  TEXT,
  note          TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: acceso público con anon key (no hay auth de Supabase)
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_access" ON family_members
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "public_access" ON readings
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- Índice para consultas por fecha
CREATE INDEX IF NOT EXISTS idx_readings_recorded_at ON readings (recorded_at DESC);
```

---

## Paso 2 — pubspec.yaml

Agregar dependencia:
```yaml
supabase_flutter: ^2.9.0
```

---

## Paso 3 — lib/models/reading.dart

Agregar campo `recordedBy`:

```dart
final String recordedBy;  // nombre del familiar que registró
```

- Constructor: agregar `required this.recordedBy`
- `toJson()`: agregar `'recordedBy': recordedBy`
- `fromJson()`: `recordedBy: json['recordedBy'] as String? ?? 'Sin nombre'`
- Agregar métodos para Supabase:

```dart
// Para insertar en Supabase (snake_case)
Map<String, dynamic> toSupabaseRow() => {
  'id': id,
  'recorded_by': recordedBy,
  'recorded_at': timestamp.toUtc().toIso8601String(),
  'glucose_value': glucoseValue,
  'moment': moment,
  'insulin_dose': insulinDose,
  'insulin_type': insulinType,
  'note': note,
};

// Para leer desde Supabase
factory Reading.fromSupabaseRow(Map<String, dynamic> row) => Reading(
  id: row['id'] as String,
  recordedBy: row['recorded_by'] as String? ?? 'Sin nombre',
  timestamp: DateTime.parse(row['recorded_at'] as String).toLocal(),
  glucoseValue: row['glucose_value'] as int,
  moment: row['moment'] as String,
  insulinDose: row['insulin_dose'] as int?,
  insulinType: row['insulin_type'] as String?,
  note: row['note'] as String?,
);
```

---

## Paso 4 — lib/services/supabase_service.dart (NUEVO)

Singleton que maneja toda la comunicación con Supabase:

```dart
class SupabaseService {
  static const _url = 'https://zhpeyepkajfptlnfspnp.supabase.co';
  static const _anonKey = 'sb_publishable_3E9Zoml0DsT3C0hjZLdoZw_sh266bN0';

  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  static SupabaseClient get _client => Supabase.instance.client;

  // Familiares
  Future<List<String>> getFamilyMembers() async { ... }
  Future<void> addFamilyMember(String name) async { ... }

  // Lecturas
  Future<List<Reading>> fetchAllReadings() async { ... }
  Future<void> pushReading(Reading r) async { ... }  // upsert
  Future<void> pushReadings(List<Reading> rs) async { ... }  // batch upsert
  Future<void> deleteReading(String id) async { ... }

  // Sync: sube lecturas locales que no están en Supabase
  Future<void> syncToRemote(List<Reading> localReadings) async { ... }

  // Merge: descarga todo y hace union con local
  Future<List<Reading>> fetchAndMerge(List<Reading> localReadings) async { ... }
}
```

---

## Paso 5 — lib/services/storage_service.dart

Agregar manejo de usuario actual y lista local de familiares:

```dart
static const _userKey = 'current_user_name';
static const _membersKey = 'family_members_cache';
static const _syncDoneKey = 'initial_sync_done';

String? getCurrentUser() => _prefs.getString(_userKey);
Future<void> setCurrentUser(String name) => _prefs.setString(_userKey, name);

List<String> getCachedMembers() { ... }
Future<void> cacheMembersLocally(List<String> names) { ... }

bool get initialSyncDone => _prefs.getBool(_syncDoneKey) ?? false;
Future<void> markInitialSyncDone() => _prefs.setBool(_syncDoneKey, true);
```

---

## Paso 6 — lib/main.dart

Cambios:

1. Inicializar Supabase antes de `runApp`:
```dart
await SupabaseService.initialize();
```

2. En `GlucosaApp.build()`, usar `home: const SplashRouter()` en vez de `HomeScreen` directamente.

3. Nuevo widget `SplashRouter`:
```dart
// Lee usuario actual de SharedPreferences
// Si no hay → navega a UserSelectScreen
// Si hay → navega a HomeScreen
```

4. `HomeScreen`: pasar `currentUser` a pantallas que lo necesiten.
5. AppBar: mostrar `👤 [nombre]` + botón `Cambiar` que abre `UserSelectScreen`.
6. En `_loadReadings()`: después de cargar local, disparar sync en background.

---

## Paso 7 — lib/screens/user_select_screen.dart (NUEVO)

Pantalla de selección de familiar:

- Header: "¿Quién eres?" con ícono de familia
- Lista de familiares (cards con avatar de inicial + nombre)
  - Se carga desde Supabase con fallback a caché local
- Botón "＋ Agregar familiar" → dialog con campo de texto para el nombre
- Al tocar un familiar:
  - Guarda en SharedPreferences (`current_user_name`)
  - Navega a `HomeScreen` (o hace pop si viene de "Cambiar")
- Sin botón de regreso si es la primera vez (obligatorio seleccionar)

---

## Paso 8 — lib/screens/register_screen.dart

- Recibe `currentUser` como parámetro
- En `_save()`: usar `recordedBy: widget.currentUser`
- Mostrar badge informativo debajo del botón guardar:
  ```
  📝 Registrando como: Uriel Navarrete
  ```
- Después de `storage.addReading()`:  
  `SupabaseService().pushReading(reading)` (fire-and-forget, error silencioso)

---

## Paso 9 — lib/screens/history_screen.dart

En `_readingCard()`, agregar debajo del nombre del momento:
```dart
Text('👤 ${r.recordedBy}',
    style: TextStyle(fontSize: 11, color: AppColors.muted))
```

---

## Paso 10 — lib/screens/data_screen.dart

- CSV: agregar columna "Registrado por" en el export
- Agregar botón "🔄 Sincronizar con nube" que llama `SupabaseService().fetchAndMerge()`
- Mostrar timestamp de última sincronización

---

## Flujo de sync offline

```
App inicia
  ↓
Carga local (instantáneo) → muestra UI
  ↓ (background)
fetchAndMerge():
  - Descarga readings de Supabase
  - Union con local por ID
  - Guarda merged en local
  - setState() con nuevos datos

Al guardar un registro:
  - save local (inmediato)
  - pushReading() con try/catch silencioso

Migración inicial (una sola vez):
  - syncToRemote(localReadings)
  - Registros sin recordedBy → recorded_by = 'Importado'
  - markInitialSyncDone()
```

---

## Archivos afectados

| Acción | Archivo |
|--------|---------|
| CREAR  | `lib/services/supabase_service.dart` |
| CREAR  | `lib/screens/user_select_screen.dart` |
| MODIFICAR | `lib/models/reading.dart` |
| MODIFICAR | `lib/services/storage_service.dart` |
| MODIFICAR | `lib/main.dart` |
| MODIFICAR | `lib/screens/register_screen.dart` |
| MODIFICAR | `lib/screens/history_screen.dart` |
| MODIFICAR | `lib/screens/data_screen.dart` |
| MODIFICAR | `pubspec.yaml` |

---

## Verificación

1. MCP `apply_migration` → confirmar tablas creadas con `list_tables`
2. `flutter pub get` sin errores
3. `flutter analyze` sin errores
4. `flutter build apk --release` exitoso
5. Prueba manual:
   - Primera apertura → muestra UserSelectScreen
   - Agregar "Uriel Navarrete" → lista lo muestra → seleccionar
   - Registrar glucosa → aparece en historial con "👤 Uriel Navarrete"
   - Abrir en otro dispositivo con misma anon key → ve los mismos registros
