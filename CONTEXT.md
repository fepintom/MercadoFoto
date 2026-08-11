# Contexto completo — OkVenta (app "MercadoFoto")

> Este archivo existe para que cualquier sesión de Claude (o cualquier
> desarrollador) que retome este proyecto tenga el contexto completo sin
> depender de memoria de conversación previa. Léelo primero.

Estás retomando el desarrollo de **OkVenta**, un marketplace chileno (compra/venta de productos + oferta/búsqueda de servicios) con escrow de pagos.

## Stack y repositorio

- **Repo**: `/Users/user/MercadoFoto` (GitHub: `fepintom/MercadoFoto`)
- **Frontend**: Flutter (iOS primero; bundle ID `com.okventa.app`, Team ID `ASN79QKDK7`)
- **Backend**: FastAPI (Python) — `backend/main.py` es el archivo principal (~3000 líneas), con módulos en `backend/database/*.py` (uno por dominio: ordenes, usuarios, servicios, notifications, evidencias, bitacora, agent_logs, tracking, ayuda, entregas) y `backend/routers/okdelivery.py` para el flujo de repartidores
- **Base de datos**: SQLite puro (sin ORM), un solo archivo `publicaciones.db` en Render (`/data/database/publicaciones.db`), uploads en `/data/uploads/`
- **Auth/push**: Firebase (Auth + Firebase Admin SDK para FCM). NO se usa Firestore — todo el dato de negocio vive en SQLite
- **Pagos**: Mercado Pago vía `backend/services/mp_service.py`. Variable `PAGOS_TEST_MODE=true` en Render simula pagos aprobados al instante sin llamar a MP real — clave para probar el flujo sin plata real
- **Deploy backend**: Render (`https://okventa-backend.onrender.com`), servicio configurado para deployar desde la rama **`refactor/app-architecture-v1`**, NO desde `main` — **siempre hay que pushear a ambas ramas** (mergear `main` → `refactor/app-architecture-v1`)
- **Deploy app**: GitHub Actions (`.github/workflows/ios_testflight.yml`) dispara build+upload a TestFlight automáticamente con cada push a `refactor/app-architecture-v1` (~7 min)
- **ADMIN_TOKEN** por defecto: `okventa-admin-2026` (protege endpoints `/admin/*`)
- Usuarios de prueba en producción: vendedor = user_id 1, comprador = user_id 3 (igallardo)

## Estado de credenciales e infraestructura (verificado)

- **GitHub Actions secrets**: los 6 necesarios para firmar y subir a TestFlight ya están cargados y funcionando — `CERTIFICATE_P12`, `CERTIFICATE_PASSWORD`, `PROVISIONING_PROFILE`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`. No hace falta regenerarlos.
- **App Store Connect API Key** activa: nombre "Codemagic" (histórico, pero es la que usa el CI actual), Key ID `B4K3Y9G229`, Issuer ID `0f80fb60-e555-46f6-9c4b-79a3ea9b96f8`, rol Administración. Copia local del `.p8` en `~/Downloads/AuthKey_B4K3Y9G229.p8`.
- **Token de GitHub** (para `git push` local): rotado — el remoto (`git remote -v`) usa un Personal Access Token classic vigente hasta el 9 de sep 2026, scopes `repo, workflow`. El token viejo y el de "Codemagic" (sin uso) ya fueron eliminados de GitHub.
- **Repo git**: limpio — se eliminó un worktree huérfano (`.claude/worktrees/wonderful-bartik-d00f13`) que había quedado trackeado como gitlink (commit `6510e7d`).
- **Pendiente si se traspasa a otra máquina/humano** (no aplica si sigue siendo la misma Mac): acceso a Render (dashboard del backend), acceso a Firebase Console, invitar como colaborador en GitHub, invitar en App Store Connect (Users and Access → People).
- **`ANTHROPIC_API_KEY`**: aún no configurada en Render — sin ella, el agente de soporte de la app degrada automáticamente a crear tickets humanos en vez de responder con IA.

## Flujo de venta — máquina de estados

```
pendiente_pago → pago_confirmado → en_camino → entrega_reportada → entregado
                                                                   ↘ en_disputa
                                                                   ↘ reembolsado
pendiente_pago → cancelado (expira solo a las 24h sin pago)
```

`_procesar_pago_aprobado()` en `main.py` es la única fuente de verdad para pago aprobado, sea test mode o webhook real de MP — no duplicar esa lógica.

### Los 3 flujos de negocio
1. **Compra de producto**: publicación → pago MP (retenido) → vendedor elige entrega → confirmación → libera pago
2. **"Busco servicio"** (`tipo='busco'`): usuario publica lo que necesita, oferentes contactan por chat
3. **"Ofrezco servicio"** (`tipo='ofrezco'`): usuario publica su servicio con certificado opcional (revisión manual del equipo); si se contrata con pago, sigue la MISMA máquina de estados/escrow que un producto

## Features construidas (en orden cronológico)

### 1. Tracking en vivo "Lo entrego yo"
Vendedor transmite GPS cada 10s (`POST /ordenes/{id}/tracking`), comprador ve mapa con polling cada 5s (`GET /ordenes/{id}/tracking`), estilo Uber. Pantallas: `entrega_vendedor_screen.dart`, `seguimiento_entrega_screen.dart`. Todo TileLayer de OSM necesita `userAgentPackageName: 'com.okventa.app'` o da 403.

### 2. Doble confirmación de entrega con evidencia fotográfica
- Vendedor reporta entrega con foto (**solo cámara, nunca galería**) + GPS → `POST /ordenes/{id}/reportar-entrega` → `entrega_reportada`
- Comprador confirma con foto → `POST /ordenes/{id}/confirmar-recepcion` → `entregado`, libera fondos
- Comprador reporta problema (motivo+descripción+foto) → `POST /ordenes/{id}/reportar-problema` → `en_disputa`
- Tabla `entregas_evidencia` con `UNIQUE(orden_id, tipo)` — nunca se sobreescribe
- Jobs automáticos (`backend/scripts/run_delivery_worker.py`): recordatorio 24h, auto-confirmación 48h (nunca si hay disputa), expiración de `pendiente_pago` a las 24h
- Solo aplica a `delivery_method='yo'`. OkVenta Delivery tiene su propio flujo (`entregas_okdelivery`); Blue Express se actualiza manual/por guía

### 3. Etiqueta de envío con doble QR
`etiqueta_envio_screen.dart` con foto del producto, dirección, y 2 QR client-side (`qr_flutter`):
- QR "Ruta" → `okventa://orden/{id}/mapa`
- QR "Confirmar entrega" → `okventa://orden/{id}/confirmar-entrega?token={token}` (token persiste al reimprimir), validado en `POST /ordenes/{id}/confirmar-entrega`
- Imprimir vía `printing`, deep links con `app_links` + `Info.plist` (scheme `okventa`)

### 4. Bitácora auditable
Tabla `ordenes_bitacora` (append-only, hora+lat/lng por evento). Backoffice:
- `GET /admin/ordenes/{id}/bitacora?token=`
- `GET /admin/ordenes?token=&limit=&estado=`

### 5. Notificaciones
Push (FCM) + tabla `notifications` con `leido`. `notification_router.dart` es el punto único tipo→pantalla. `POST /notificaciones/{uid}/marcar-leidas` al abrir el panel.

### 6. Agente de soporte con IA
`backend/services/support_agent.py` (SDK Anthropic):
- Haiku 4.5 por defecto, escala a Sonnet 5 ante frustración/disputa/pregunta repetida
- Tools: `buscar_faq` (lee `backend/support/faq.md`), `consultar_orden`, `consultar_pago`, `solicitar_cancelacion`, `escalar_a_humano`
- Guardrail: `solicitar_cancelacion` nunca ejecuta directo — token de 30 min, confirmación explícita en el chat, `POST /support/confirm-action` revalida todo antes de ejecutar
- Bitácora en `agent_logs` — `GET /admin/agent-logs?token=&resumen=true`
- Sin `ANTHROPIC_API_KEY` degrada a ticket humano (nunca error técnico visible)
- Frontend: `soporte_chat_screen.dart`, botón "?" en Detalle de producto y Mis Órdenes

### 7. OkVenta Delivery — pausado temporalmente
Oculto del checkout (`seleccionar_entrega_screen.dart`) detrás de `okDeliveryDisponible = false` en `app_config.dart`. Registro de repartidores nuevos bloqueado, muestra `delivery_proximamente_screen.dart` con sello ilustrado (`ok_delivery_stamp.dart`, `CustomPainter` puro). Código real (`delivery_registro_screen.dart`) intacto, solo desconectado. Repartidores ya registrados pueden seguir editando su perfil.

### 8. Bugs corregidos (última ronda de QA)
Foto de perfil (nombre de archivo único), dirección manual como fallback, RUT en Datos bancarios, "Cómo cuidamos tus datos" con destino, Favoritos/Historial en menú de cuenta, unificación del flujo "reportar problema", 3 tipos de notificación sin ruta agregados al router.

**Pendientes de decisión de producto** (no implementados, requieren definición): selección/eliminación en bloque de publicaciones; si el flujo de compra de un servicio debe saltar el checkout MP e ir directo al chat; contenido real de "Historial".

## Sistema de diseño

`app/lib/theme/app_theme.dart` — `AppColors.primary` = `#D62B2B` (rojo), `carbon`, `grayMid`, `background` = `#F2F2F7`, `surface` = blanco, `divider` = `#E0E0E5`. Nunca `Colors.blue/grey/red/white` hardcoded, siempre `AppColors.*`.

## Cómo verificar cambios (patrón establecido)

1. Editar código
2. `flutter analyze --no-pub` debe dar 0 errores antes de commitear
3. Para UI compleja/visual: preview rápido con `flutter run -d chrome -t lib/archivo_temporal.dart --web-port=XXXX`, mirar y borrar el archivo temporal
4. Commit + push a `main`, luego `git checkout refactor/app-architecture-v1 && git merge main && git push`, volver a `main`
5. Verificar deploy backend con curl (Render puede tardar ~1-2 min en cold start)
6. Verificar build de TestFlight con `gh run list --workflow=ios_testflight.yml --limit=1`

## Próximos pasos sugeridos

- Configurar `ANTHROPIC_API_KEY` en Render para activar el agente de soporte con IA real
- Definir con producto: selección múltiple en publicaciones, flujo de compra de servicios, contenido de "Historial"
- Copy legal real para "Cómo cuidamos tus datos" (el actual es un placeholder factual)
- Activar OkVenta Delivery (`okDeliveryDisponible = true`) cuando haya equipo de repartidores
- Payout automático a vendedores (hoy es coordinación manual)
- Migrar tiles de mapa de OpenStreetMap a un proveedor con SLA para producción a escala
