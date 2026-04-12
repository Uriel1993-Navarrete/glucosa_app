# Control de Salud Familiar — Flutter App

App móvil para el registro de signos vitales en familia. Funciona sin internet (modo offline-first) y sincroniza con la nube cuando hay conexión.

## Métricas registradas

| Métrica | Unidad | Estados |
|---|---|---|
| Glucosa | mg/dL | Bajo / Normal / Alto / Muy alto |
| Oxigenación (SpO2) | % | Normal / Bajo / Crítico |
| Presión arterial | mmHg (sistólica/diastólica) | Normal / Elevada / Grado 1 / Grado 2 / Crisis |
| Pulso | bpm | Normal / Bradicardia / Taquicardia |

## Características

- Selector de 4 métricas en el formulario de registro
- Registro con momento del día (ayuno, antes/después de comer, noche) — solo glucosa
- Registro de insulina (dosis y tipo) — solo glucosa
- Gestión de **familiares** (quién registra) y **pacientes** (a quién se le mide)
- Sincronización en la nube con Supabase (automática al recuperar conexión)
- Caché local para funcionar completamente sin internet
- Historial con filtros agrupado por fecha
- Gráfica semanal con navegación por semanas
- Exportar JSON / CSV para compartir o llevar al médico
- Importar JSON desde el dispositivo
- Guardado doble: SharedPreferences + archivo de respaldo en documentos del teléfono

## Pantallas de flujo inicial

Al abrir la app por primera vez (o si no hay usuario/paciente seleccionado), se pasa por:

1. **UserSelectScreen** — ¿Quién registra? (selecciona o agrega familiar)
2. **PatientSelectScreen** — ¿A quién se le mide? (selecciona o agrega paciente)
3. **HomeScreen** — App principal con 4 pestañas

## Setup rápido

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Compilar APK para Android
flutter build apk --release

# El APK queda en:
# build/app/outputs/flutter-apk/app-release.apk
```

## Instalar en el teléfono

1. Copia el APK al teléfono (USB, WhatsApp, Drive, etc.)
2. Abre el archivo en el teléfono
3. Si pide permiso para instalar apps de fuentes desconocidas → Permitir
4. Instalar

## Compartir con la familia

1. Abre la app → pestaña **Datos**
2. Toca **"Compartir con la familia"**
3. Selecciona WhatsApp y manda el archivo
4. El familiar recibe el archivo, lo abre con la app → pestaña Datos → "Cargar historial"
5. Los datos quedan guardados automáticamente en su teléfono

## Estructura del proyecto

```
lib/
  main.dart                          # App entry, SplashRouter, HomeScreen con tabs
  theme.dart                         # Colores, ThemeData, kMoments, kInsulinTypes
  models/
    reading.dart                     # Modelo Reading + enum GlucoseStatus
    oxygen_reading.dart              # OxygenReading + enum SpO2Status
    blood_pressure_reading.dart      # BloodPressureReading + enum BPStatus
    heart_rate_reading.dart          # HeartRateReading + enum HRStatus
    metric_type.dart                 # enum MetricType (glucosa, O₂, presión, pulso)
  services/
    storage_service.dart             # SharedPreferences + backup JSON + caché de familiares/pacientes
    supabase_service.dart            # Sincronización en la nube (Supabase)
  screens/
    user_select_screen.dart          # Seleccionar quién registra (familiar)
    patient_select_screen.dart       # Seleccionar a quién se mide (paciente)
    register_screen.dart             # Formulario de registro (selector de 4 métricas)
    history_screen.dart              # Historial con filtros
    chart_screen.dart                # Gráfica semanal (fl_chart)
    data_screen.dart                 # Exportar/importar/compartir
```

## Umbrales clínicos

**Glucosa (mg/dL)**
- Bajo: < 70
- Normal: 70–130
- Alto: 130–180
- Muy alto: > 180

**SpO2 (%)**
- Normal: ≥ 95
- Bajo: 90–94
- Crítico: < 90

**Presión arterial (mmHg)**
- Normal: sistólica < 120 y diastólica < 80
- Elevada: sistólica 120–129
- Grado 1: sistólica 130–139 o diastólica 80–89
- Grado 2: sistólica ≥ 140 o diastólica ≥ 90
- Crisis: sistólica > 180 o diastólica > 120

**Pulso (bpm)**
- Bradicardia: < 60
- Normal: 60–100
- Taquicardia: > 100

## Dependencias principales

| Paquete | Uso |
|---|---|
| shared_preferences | Almacenamiento principal en el dispositivo |
| path_provider | Ruta para archivo de backup automático |
| share_plus | Compartir archivos por WhatsApp / correo |
| file_picker | Seleccionar JSON para importar |
| fl_chart | Gráfica semanal |
| intl | Fechas en español |
| uuid | IDs únicos para cada registro |
| supabase_flutter | Sincronización en la nube |
| connectivity_plus | Detectar estado de conexión para sync automático |
