# 🩸 Control de Glucosa — Flutter App

App móvil para registro de glucosa e insulina. Funciona sin internet, guarda automáticamente en el teléfono.

## Características
- Registro de glucosa con momento del día (ayuno, antes/después de comer, noche)
- Registro de insulina (dosis y tipo)
- Historial con filtros
- Gráfica semanal con fl_chart
- Exportar JSON para compartir por WhatsApp
- Importar JSON (queda guardado automáticamente, sin pasos extra)
- Exportar CSV para el médico
- Guardado doble: SharedPreferences + archivo en documentos del teléfono

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
  main.dart                    # App entry, HomeScreen con tabs
  theme.dart                   # Colores, ThemeData
  models/
    reading.dart               # Modelo Reading + GlucoseStatus
  services/
    storage_service.dart       # SharedPreferences + backup JSON
  screens/
    register_screen.dart       # Formulario de registro
    history_screen.dart        # Historial con filtros
    chart_screen.dart          # Gráfica semanal (fl_chart)
    data_screen.dart           # Exportar/importar/compartir
```

## Dependencias principales

| Paquete | Uso |
|---|---|
| shared_preferences | Almacenamiento principal en el dispositivo |
| path_provider | Ruta para archivo de backup automático |
| share_plus | Compartir archivos por WhatsApp / correo |
| file_picker | Seleccionar JSON para importar |
| fl_chart | Gráfica de glucosa semanal |
| intl | Fechas en español |
| uuid | IDs únicos para cada registro |
