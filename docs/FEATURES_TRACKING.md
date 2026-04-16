# Seguimiento de Funcionalidades

Archivo de seguimiento del estado de implementación de los módulos de la aplicación.

---

## Métricas de Salud (completado)

| Funcionalidad | Estado | Notas |
|---|---|---|
| Registro de glucosa | ✅ Completado | Con momento, insulina y notas |
| Registro de oxigenación (SpO2) | ✅ Completado | Con umbrales normal/bajo/crítico |
| Registro de presión arterial | ✅ Completado | Con 5 estados clínicos |
| Registro de pulso / FC | ✅ Completado | Con bradicardia/normal/taquicardia |
| Historial con filtros | ✅ Completado | Filtro por fecha y estado |
| Gráfica semanal | ✅ Completado | Navegación por semanas |
| Exportar JSON/CSV | ✅ Completado | Todas las métricas |
| Sincronización Supabase | ✅ Completado | Merge bidireccional |
| Multi-usuario / multi-paciente | ✅ Completado | Con selección en AppBar |

---

## Fase 1 — Medicamentos

| Funcionalidad | Estado | Notas |
|---|---|---|
| Modelo Medication (local) | ✅ Completado | `lib/models/medication.dart` |
| Modelo con Supabase row | ✅ Completado | `toSupabaseRow` / `fromSupabaseRow` |
| CRUD local (SharedPreferences) | ✅ Completado | `storage_service.dart` |
| Tabla `medications` en Supabase | ✅ Completado | Migración aplicada |
| Sync bidireccional Supabase | ✅ Completado | `supabase_service.dart` |
| Pantalla lista de medicamentos | ✅ Completado | Agrupada por médico/receta |
| Formulario alta/edición | ✅ Completado | `medication_form_screen.dart` |
| Detalle en BottomSheet | ✅ Completado | Con editar y eliminar |
| Acceso desde Drawer | ✅ Completado | Menú lateral en HomeScreen |
| Filtro activos / todos | ✅ Completado | Toggle en AppBar |

---

## Fase 2 — Citas Médicas

| Funcionalidad | Estado | Notas |
|---|---|---|
| Modelo MedicalAppointment (local) | ✅ Completado | `lib/models/appointment.dart` |
| Modelo con Supabase row | ✅ Completado | `toSupabaseRow` / `fromSupabaseRow` |
| CRUD local (SharedPreferences) | ✅ Completado | `storage_service.dart` |
| Tabla `appointments` en Supabase | ✅ Completado | Migración aplicada |
| Sync bidireccional Supabase | ✅ Completado | `supabase_service.dart` |
| Mini calendario mensual | ✅ Completado | `table_calendar` — `appointments_screen.dart` |
| Lista de citas por día | ✅ Completado | Con hora, médico, especialidad, ubicación |
| Formulario alta/edición | ✅ Completado | `appointment_form_screen.dart` |
| Marcar cita como completada | ✅ Completado | Switch en formulario |
| Notas post-cita (resultado) | ✅ Completado | Campo editable en formulario |
| Acceso desde Drawer | ✅ Completado | Menú lateral en HomeScreen |

---

## Fase 3 — Notificaciones (pendiente)

| Funcionalidad | Estado | Notas |
|---|---|---|
| Recordatorio de medicamentos | ⏳ Pendiente | 15 min antes del horario configurado |
| Recordatorio de citas | ⏳ Pendiente | 1 día antes de la cita |
| Configurar notificaciones | ⏳ Pendiente | Activar/desactivar por medicamento o cita |

**Dependencia a agregar:**
```yaml
flutter_local_notifications: ^17.0.0
```

**Notas de implementación:**
- Los horarios de medicamentos ya están en formato `"HH:mm"` listos para scheduling
- Las fechas de citas ya tienen fecha y hora exacta

---

## Fase 4 — Sincronización con Google Calendar (pendiente)

| Funcionalidad | Estado | Notas |
|---|---|---|
| Autenticación Google OAuth | ⏳ Pendiente | |
| Exportar citas a Google Calendar | ⏳ Pendiente | |
| Importar citas desde Google Calendar | ⏳ Pendiente | |

---

## Arquitectura de módulos

```
lib/
├── models/
│   ├── reading.dart              # Glucosa
│   ├── oxygen_reading.dart       # SpO2
│   ├── blood_pressure_reading.dart # Presión arterial
│   ├── heart_rate_reading.dart   # Pulso
│   ├── medication.dart           # Medicamentos (nuevo)
│   └── appointment.dart          # Citas médicas (nuevo)
├── services/
│   ├── storage_service.dart      # CRUD local (SharedPreferences)
│   └── supabase_service.dart     # Sync remoto (Supabase)
├── screens/
│   ├── register_screen.dart      # Registrar métricas
│   ├── history_screen.dart       # Historial de métricas
│   ├── chart_screen.dart         # Gráfica semanal
│   ├── data_screen.dart          # Exportar/importar datos
│   ├── medications_screen.dart   # Lista medicamentos (nuevo)
│   ├── medication_form_screen.dart # Formulario medicamento (nuevo)
│   ├── appointments_screen.dart  # Calendario citas (nuevo)
│   └── appointment_form_screen.dart # Formulario cita (nuevo)
└── main.dart                     # HomeScreen + Drawer + sync
```

---

*Última actualización: Abril 2026*
