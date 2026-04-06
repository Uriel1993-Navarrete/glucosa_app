# CLAUDE.md

Este archivo proporciona orientación a Claude Code (claude.ai/code) al trabajar con el código de este repositorio.

## Descripción del proyecto

Aplicación móvil Flutter para el registro de glucosa e insulina dirigida a pacientes diabéticos. Funciona completamente sin conexión — sin llamadas a red. La interfaz está en español.

## Comandos

```bash
flutter pub get                 # Instalar dependencias
flutter run                     # Ejecutar en dispositivo/emulador conectado
flutter analyze                 # Linting (usa flutter_lints)
flutter test                    # Ejecutar todos los tests
flutter build apk --release     # Compilar APK Android → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle         # Compilar Android App Bundle
flutter test test/widget_test.dart  # Ejecutar un único archivo de test
```

## Arquitectura

La app usa el patrón simple de `StatefulWidget` — sin librería externa de gestión de estado.

```
lib/
├── main.dart              # Punto de entrada + HomeScreen (navegación 4 pestañas, dueño de la lista de lecturas)
├── theme.dart             # AppColors, kMoments, kInsulinTypes, buildTheme()
├── models/
│   └── reading.dart       # Reading (UUID, timestamp, glucoseValue, moment, insulin, note) + enum GlucoseStatus
├── services/
│   └── storage_service.dart   # Singleton CRUD, exportación JSON/CSV, importación, SharedPreferences + archivo de respaldo
└── screens/
    ├── register_screen.dart   # Formulario para registrar una lectura
    ├── history_screen.dart    # Lista filtrada agrupada por fecha
    ├── chart_screen.dart      # Gráfica semanal fl_chart con navegación por semanas
    └── data_screen.dart       # Exportar JSON/CSV, importar, compartir, eliminar todo
```

**Flujo de estado:** `HomeScreen` carga las lecturas desde `StorageService` y las pasa (junto con callbacks `onSaved`/`onChanged`) a cada pantalla. Las pantallas hijas llaman al callback tras cada mutación para disparar un `setState` en el padre.

**Persistencia de datos:**
1. `SharedPreferences` — almacenamiento principal (lista codificada en JSON bajo una sola clave)
2. Archivo JSON en la carpeta Documentos — respaldo automático escrito en cada guardado

## Detalles del dominio

Umbrales de glucosa (mg/dL):
- Bajo: < 70
- Normal: 70–130
- Alto: 130–180
- Muy alto: > 180

Las constantes de momentos y tipos de insulina están en `theme.dart` (`kMoments`, `kInsulinTypes`) y se reutilizan en todas las pantallas.

## Dependencias

| Paquete | Propósito |
|---|---|
| `shared_preferences` | Almacenamiento local principal |
| `path_provider` | Carpeta Documentos para el archivo de respaldo |
| `share_plus` | Hoja de compartir del SO (WhatsApp, email, etc.) |
| `file_picker` | Importar archivo JSON desde el dispositivo |
| `fl_chart` | Gráfica de líneas de glucosa |
| `intl` | Formato de fechas en español |
| `uuid` | UUID v4 para IDs de Reading |
