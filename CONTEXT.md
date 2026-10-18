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

### 9. Navegación nueva + filtros + Comunidad (sep 2026)
- **Barra inferior**: "Inicio" → **Comunidad** (ícono `groups_outlined`); "Vender" → **OkMarket** (mismo diseño, abre el marketplace); "Servicios" → **OkServicios**. La lógica de vender vive ahora en el botón **"+ Publicar"** arriba a la derecha de OkMarket (abre `VenderScreen`). En OkServicios "+ Publicar"/"+ Buscar" según la pestaña.
- **Fila de filtros compartida** `widgets/barra_filtros.dart` (OkMarket y OkServicios): `[◎ Filtro de búsqueda] [Categorías ▼] [región] [cat]…  [+ Publicar]`. El filtro de búsqueda tiene dos modos: "Cerca de mí" (radio km) o "Por zona" (regiones de Chile; la región de cada publicación se deduce de su lat/lng con la ciudad de referencia más cercana, `utils/regiones_chile.dart`). Filtro y Categorías despliegan su panel debajo (categorías en una sola línea deslizable). Multi-categoría; las elegidas quedan en rojo arriba y se quitan **manteniendo presionado y arrastrando fuera** (efecto esfumado con blur + chispas, `PastillaQuitable`). El alto del encabezado anclado se calcula con `BarraFiltros.alto(panel)`.
- **Comunidad** (`screens/comunidad_screen.dart`): chat público todos-con-todos (nombre y foto del autor tocables → perfil público), emojis, anclar productos/servicios propios (tarjeta en el mensaje + franja "Anclados"). Polling cada 4 s solo con la pestaña visible. Backend: `routers/comunidad.py`, `database/comunidad.py` (tabla `comunidad_mensajes`), bot en `services/comunidad_bot.py` (bienvenida, responde a `@okventa` — IA con `ANTHROPIC_API_KEY`, reglas sin ella —, y `POST /admin/comunidad/bot/oferta?token=` para que publique una oferta). Sin moderación todavía.

- **Mapa unificado en Encontrar** (`screens/encontrar_screen.dart`, reescrita): interruptores `[Productos] [Servicios]` (se pueden ver ambos; productos = pin con foto y precio, servicios = círculo oscuro con llave, ✓ si certificado), buscador y la misma `BarraFiltros` (cerca de mí / por zona — al elegir región el mapa se encuadra ahí — y categorías según capas encendidas). Solo servicios `ofrezco`. Ficha de producto: descripción breve + línea de instalación: (a) "Instalación incluida, la hace el vendedor" (enlaza su servicio si lo publicó), (b) proveedor sugerido de OkServicios: misma categoría vía `categoriaServicioParaProducto` (nunca "Otros"), que cubra la zona (≤ max(radio_km, 25) km del producto), orden certificado > nota > cercanía, (c) "Buscar" si no hay. La pestaña Mapa de OkServicios se eliminó (queda Ofrezco/Busco/Delivery); su botón de mapa abre `EncontrarScreen(soloServicios: true)`. "Ajustar ubicación" del dueño de un servicio se movió a la ficha de servicio del mapa.

- **Ofertas** (`publicaciones.precio_original` + `descuento_pct` en GET /publicaciones y /publicaciones/{id}): al bajar el precio (`actualizar_precio` o `editar_publicacion`) se guarda el precio anterior como original; otra rebaja mantiene el original (el % es el total); subir hasta el original apaga la oferta. Bajo 5% no se anuncia. En la app, `widgets/etiqueta_oferta.dart` ("OFERTA -x%", negra en claro / blanca en oscuro) + precio de antes tachado, en la tarjeta de OkMarket y el detalle.
- **Tarjeta de OkMarket**: Nuevo verde / Usado rojo / categoría gris; botones abajo: carro (agrega, cambia a lleno si ya está; no aparece en lo propio ni agotado) y "Ver detalle" gris. Íconos y flechas de las pastillas de filtros en el rojo de Publicar (blancos en modo oscuro). Dirección del encabezado en negro.

- **Mis pagos** (perfil → "Mis pagos", `screens/mis_pagos_screen.dart`; backend `routers/pagos_usuario.py`, GET /usuarios/{id}/pagos): por cada orden pagada donde el usuario es vendedor: monto, comisión, neto, estado de la plata (liberado / retenido / 80% liberado en servicios / en disputa / reembolsado) e hitos de `ordenes_bitacora`. Resumen arriba; las órdenes de prueba no suman.
- **OkMarket compacto**: grilla por filas con IntrinsicHeight (cada fila mide lo de su tarjeta más alta; los botones quedan alineados abajo con Spacer), sin título "Okmarket" ni bolsa (el carro está en el encabezado). Corazón de favoritos en cada tarjeta (`services/favoritos_service.dart`: ids en memoria, carga una vez con GET /favoritos/{id}). Con 3+ columnas el botón dice "Ver". Textos sin gris en OkMarket/OkServicios (salvo el placeholder de los buscadores). OkServicios sin título ni botón de mapa. Detalle de producto más compacto (foto 4:3, márgenes y tipografías menores).

- **Tarjeta de OkMarket (estilo red social)**: arriba foto del vendedor (`widgets/avatar_historia.dart`, anillo degradado animado si el vendedor tiene historia vigente), nombre, ciudad (`ciudad_vendedor` desde users.ciudad/comuna, o región por lat/lng) y ⋯ con menú (`widgets/acciones_producto.dart`: perfil, valoraciones, guardar, compartir, preguntar, no me interesa, reportar → ticket de ayuda tipo "reporte", bloquear → `services/contenido_oculto_service.dart`, local en el teléfono). A la derecha de la foto: favorito, compartir (WhatsApp / copiar, sin paquete nuevo) y carro. Abajo: "Ofrece instalación" (si `instalacion_vendedor`) que abre un aviso flotante desde el enlace, y el botón "Ver detalle" ("Detalle" con 3+ columnas). Agregar al carro un producto con instalación pregunta "cotizar con instalación" (abre el chat del servicio de instalación del vendedor, con mensaje escrito, para cotización formal; si no tiene servicio publicado, el chat del producto) o "sin instalación". Bolsa → carrito en todos los íconos (salvo el botón OkMarket de la barra).

- **Valoraciones de servicios únicas** (2026-10-06): `valorar_servicio` solo inserta (sin upsert). POST /servicios/{id}/valorar → 403 si eres el dueño o nunca lo contrataste por OkVenta (`contrato_servicio`: orden tipo servicio pagada/en curso/entregada), 409 si ya calificaste. GET /servicios/{id}/mi_valoracion. La app confirma antes ("es definitiva") y luego muestra las estrellas fijas. Los productos ya estaban protegidos (/calificar).
- **Fotos de perfil livianas**: `services/imagenes.py` achica al subir (JPEG ≤640 px) y al arrancar optimiza en segundo plano las existentes >250 KB (mismo nombre). También POST /admin/fotos_perfil/optimizar?token=. App: CachedNetworkImage con memCacheWidth en Mi OkVenta, mensajes y `net_image`.
- **Comunidad**: menciones @nombre.apellido con autocompletado (GET /comunidad/usuarios), validadas en el servidor (máx 5) → notificación + push "comunidad_mencion"; tocar una mención abre el perfil. Responder con cita (`responde_a`). Menú ⋯ / mantener presionado: responder, mencionar, ver perfil, guardar, no me interesa / eliminar para mí (local), eliminar para todos (propio, DELETE /comunidad/mensajes/{id}), denunciar (ticket), bloquear.
- **Bot @okventa** (`services/comunidad_bot.py`): responde a mención, a una respuesta a su mensaje o dentro de 2 min de conversación con esa persona. Búsqueda sin tildes en productos y servicios, ofertas, intenciones (soporte, vender, pago, envío, historias…); con ANTHROPIC_API_KEY usa Haiku con memoria + FAQ + contexto. Casos complejos o "[ESCALAR]" crean ticket de ayuda tipo "comunidad". Todo queda en `comunidad_bot_log`. Admin (token ADMIN_TOKEN): GET /admin/comunidad/bot/resumen, /admin/comunidad/bot/conversaciones?escalados=true&pendientes=true, POST /admin/comunidad/bot/log/{id}/revisado.
- **Tarjeta de OkServicios = OkMarket**: encabezado con proveedor (anillo de historia) y ⋯ (`widgets/acciones_servicio.dart`), foto grande, a la derecha favorito (`routers/favoritos_servicios.py`), compartir y "Cotizar" (abre chat del servicio con mensaje escrito; se prefirió a un teléfono para no exponer el número y mantener el pago protegido). Grilla de 2 columnas por defecto.
- **Sin botón "Ver detalle"** en ninguna tarjeta: se toca la foto (ahora 4:5, recortada tipo Mercado Libre).
- **Logo diurno nuevo** (`assets/images/home.png`, fondo transparente, mismo tamaño/posición) y **5 banners nuevos** (`banner1-5.jpg`, 1600x640, carrusel 2.5:1; se quitó el de Blue Express).
- **Historias** (`routers/historias.py`, tabla historias; `services/historias_service.dart`): POST /historias (foto ≤1280 px), vigentes 24 h, destacadas sin vencimiento. En Mi OkVenta: "+" rojo en la foto para subir (`screens/subir_historia_screen.dart`), tocar la foto abre tus historias. Visor (`screens/historia_viewer_screen.dart`): barras, 5 s, toques izq/der, mantener para pausar; si es tuya, ❤️ "Destacar", borrar y vistas. `widgets/destacadas_fila.dart` en Mi OkVenta y perfil público. `AvatarHistoria(userId:)` escucha `HistoriasService.activos`: el anillo brilla y abre las historias (si no hay, va al perfil).

- **Barra de menú permanente** (2026-10-07): `HomeScreen` tiene un `Navigator` interno (Pages API, raíz = encabezado + `IndexedStack`) sobre la barra; todo lo que se abre desde las pestañas se apila ahí y la barra no se pierde. Pestañas: 0 OkMarket, 1 Alertas, 2 OkServicios, 3 Comunidad, 4 Encontrar (`EncontrarScreen(esPestana: true)`), 5 Mi OkVenta (`MiCuentaScreen(esPestana: true)`, se recrea al entrar). 1/4/5 se construyen recién al visitarlas y no llevan el encabezado. Tocar el menú cierra lo apilado. `shellNavigatorKey` (navigation_service) apunta a ese navegador y `rootContext` lo prefiere (push y deep links abren con barra). Van al navegador raíz (pantalla completa): historias, visor de fotos del producto, visor de video de chats, y el login al cerrar sesión. El teclado: el Scaffold de afuera no se encoge; lo hace el de la raíz de pestañas o el de cada pantalla.
- **Notificaciones = pestaña** (`screens/notificaciones_screen.dart`): pantalla completa, agrupadas por Hoy/Ayer/Esta semana/Anteriores, filtros con `BarraFiltros(mostrarDistancia: false, etiquetaCategorias: 'Filtrar')`: Compras, Ventas, Preguntas (incluye chats), Comunidad. El servidor agrega `categoria` a cada notificación (`database/notifications.py`, por el rol del usuario en la orden si hay `orden_id`; si no, por tipo). Entrar marca leídas. Límite 100.
- **Filtros visibles**: el botón Categorías queda rojo y dice "Categorías · N"; si hay pastillas fuera de la vista aparece en el borde "‹ N filtros" (rojo, se mueve) que desliza hasta ellas; al agregar una, la fila se desliza sola. Tocar una pastilla muestra un globo "Arrastra para eliminar el filtro"; al arrastrar, "Suelta para eliminar" (rojo) cuando ya se quita. Lupa de los buscadores en el rojo de los íconos (`colorIconoPastilla`).
- **Grilla**: mínimo 2 por fila (OkMarket 2–4, OkServicios 2–4, sin vista de lista), menos espacio (separación 6, márgenes 6).
- **Visualizaciones** (`routers/vistas.py`, tabla `vistas_items`): POST /vistas?tipo=producto|servicio&item_id=&visitante= (1 por persona por día, el dueño no cuenta; anónimos con id local). `vistas` en GET /publicaciones, /publicaciones/{id}, /servicios, /servicios/{id}. GET /vistas/top_productos?limite=5&dias=30 (solo disponibles). App: `services/vistas_service.dart` (cuenta al abrir el detalle; `EtiquetaVistas` 👁 abajo a la izquierda de la foto en tarjetas; texto en el detalle). Comunidad: chat arriba y `widgets/top_vistos.dart` ("Lo más visto · top 5 del mes") en la mitad de abajo; se esconde con el teclado.
- **Encontrar**: al abrir encuadra el mapa (con radio: el círculo; sin radio: tu ubicación + los 12 más cercanos).

- **Detalle de producto rediseñado** (2026-10-08, según maqueta): arriba pastillas (izq.) y vendedor con nombre subrayado + foto grande con anillo de historia (der.); título grande; estrellas | resumen de valoraciones (abre evaluaciones); precio grande en recuadro (color de texto, ya no rojo); fila "⚡ Puedes recibirlo hoy | 🛒 N vendidos | 👁 N"; descripción; "Medios de pago" con "Ver todos" (hoja con tarjetas, débito/Webpay, Mercado Pago y Compra protegida); Devolución gratis | Compra protegida; Información adicional en columnas SKU | Stock | Código universal (EAN) con "Editar ›" y ayuda para el dueño; botones Editar/Eliminar más altos.
- **Pastillas unificadas** (`widgets/pastilla_etiqueta.dart`): Usado rojo claro (antes naranjo), Nuevo verde claro, categoría gris, texto oscuro en ambos modos. Usadas en tarjetas de OkMarket, categoría de OkServicios, vista previa al publicar y detalle.
- **TestFlight**: `concurrency` en el workflow cancela ejecuciones duplicadas de la misma rama.

- **Espera al publicar** (2026-10-12, `widgets/espera_publicacion.dart`): mientras la IA analiza (`vender_screen`) o se sube (`confirmacion_screen`, `venta_manual_screen`) la pantalla se divide en **Jugar** | **Esperar** (temporizador con el tiempo estimado: promedio móvil de las últimas duraciones por etapa, guardado en el teléfono). Jugar abre **OkVenta Invaders** (`widgets/juegos/okventa_invaders.dart`, reemplaza a Space Invaders por copyright: Okventín visto desde arriba dispara ✓ a cajas truchas, etiquetas falsas y bichos de spam) o **Memorice OkVenta** (`widgets/juegos/okventa_memorice.dart`, 8 parejas con Okventín y logos de la app, intentos, tiempo y récord). Abajo: "Desliza hacia arriba para seguir mirando": vuelve a OkMarket y el trabajo sigue en segundo plano.
- **Borradores** (`services/borradores_service.dart`, `screens/borradores_screen.dart`, local en el teléfono con fotos copiadas a documentos de la app): si el usuario se va mientras la IA analiza, queda un borrador "analizando" → "listo" (o "error", reintentable) y se avisa. Salir de la confirmación sin publicar también guarda (o actualiza) el borrador. Ícono de borradores con número en el encabezado, antes del carro. `ConfirmacionScreen(imagenesExtra:, borradorId:)`; al publicar se borra el borrador; si falla en segundo plano, queda en Borradores.
- **Fotos de publicación con marca** (`backend/services/marca_agua.py`, usado por `quitar_fondo`): sin fondo (rembg), recortada y centrada en lienzo cuadrado 1000 px gris de estudio con sombra, texto diagonal "OK Venta App" tenue y logo "✓ OK Venta APP" al centro. Fuentes DejaVu en `backend/assets/fonts`. Solo afecta fotos nuevas.
- **Detalle de producto**: sin barra superior; la foto (cuadrada, fondo gris) lleva encima volver (izq.) y ayuda, favorito, compartir y OkServicios (der.).
- **Comunidad**: arriba "🔥 Más vendidos · Top 5 del mes" (`widgets/mas_vendidos_franja.dart`, GET /vistas/mas_vendidos: órdenes pagadas del mes, se completa con los más vistos y entonces dice "Lo más visto") y "📌 Fijados" (comentarios fijados por el usuario desde ⋯ —locales— + productos/servicios anclados; "Ver todos"). Lupa para buscar en el chat. Fondo animado en pixel art (`widgets/fondo_pixel_okventin.dart`): Okventín camina por la ciudad en loop de 18 s, mira hacia arriba, salta y entrega un paquete; 12 cps, se pausa fuera de la pestaña. Las franjas se esconden al escribir.
- Lupas de búsqueda en rojo (`colors.primary`).

- **Dirección en un ícono** (2026-10-12): en el encabezado la dirección ya no ocupa el centro; un pin (rojo si hay dirección) abre una tarjeta flotante que "emerge" del ícono con la dirección actual, las otras para cambiar y botones Agregar / Editar (→ MisDirecciones).
- **Comunidad con más pantalla para el chat**: sin título; barra fina con "🔥 TOP del mes" + ojo (esconde/muestra las tarjetitas, se recuerda) y "📌 Fijados N ▾" desplegable (parte cerrado; "Ver todos" al final de la fila). Caja de texto más grande (48 px, letra 15,5, emoji dentro) y un "+" con: Enviar mi ubicación, Anclar lo que vendes, Buscar en el chat.
- **Ubicación en el chat**: hoja "Enviar mi ubicación" (`widgets/compartir_ubicacion.dart`) con mapa, sugerencias ("Estoy aquí, necesito…") y texto. En Comunidad se guarda redondeada (~100 m, columna `ubicacion` de `comunidad_mensajes`, campos `lat/lng` en POST); en privado, exacta. Se dibuja con `widgets/mapa_mini.dart` (toca → app de mapas).
- **Mensajes privados** (`routers/privados.py`, tabla `mensajes_privados`; `services/privados_service.dart`; `screens/chat_privado_screen.dart`): tocar la foto o el nombre de alguien en Comunidad → "Enviar mensaje privado / Ver perfil / Mencionar". Notificación + push tipo `privado` (categoría Preguntas; el router abre el chat). En Mensajes aparece arriba la fila "Privados" con no leídos.

- **Comunidad, buscar como Ctrl+F** (2026-10-12): barra fina = [🔥 TOP 👁] [📌 Fijados N ▾] … [🔍@]. La lupa abre una fila: campo "Buscar o @nombre" (Enter lo deja como pastilla amarilla a la derecha; se pueden sumar varias), contador x/n de apariciones (sin tildes ni mayúsculas) y ▲▼ para saltar entre ellas; no oculta mensajes, resalta (amarillo; la actual naranjo, subrayado). Mis burbujas en modo oscuro usan un rojo apagado (0xFFA3302D).
- **Notificaciones**: campo "Buscar por palabra clave" (todas las palabras deben aparecer) además de los filtros.
- **Categorías como íconos**: el panel de categorías de `BarraFiltros` (OkMarket, OkServicios, Encontrar, Notificaciones) son círculos con el ícono rojo y el nombre abajo; elegida = círculo rojo con ícono blanco y ✓ (tocar de nuevo la quita). Las categorías puestas arriba son círculos rojos solo con ícono (`PastillaQuitable(soloIcono:)`; al tocar, el globo dice el nombre). "Filtro de búsqueda" ahora es "Radio de búsqueda".
- **Buscar por texto = filas**: con texto en el buscador, OkMarket y OkServicios muestran resultados en filas (`widgets/fila_resultado.dart`: foto 96 px, título completo hasta 3 líneas, precio, pastillas, lugar, 👁).
- **Cotizaciones nuevas**: editor `screens/cotizacion_editor_screen.dart` (De/Para, ítems con cantidad y precio unitario, descuento, impuestos, total, retención 20 %/pago inicial 80 % según el Seguro Garantía, válida hasta, entrega, forma de pago, observaciones; Imprimir, Guardar borrador, Enviar). Desde el chat del servicio envía al servidor `datos` (JSON) y el servidor recalcula el total y genera el PDF nuevo (`services/cotizacion_service.py`, diseño de la maqueta con Okventín, fuentes DejaVu, ~140 KB). PDF local con el mismo diseño (`services/cotizacion_pdf.dart`, paquete pdf/printing). **Mis cotizaciones** (Mi OkVenta; `services/cotizaciones_guardadas_service.dart`): guardadas en el teléfono con su PDF, se borran solas a los 30 días; aviso fijo arriba; compartir PDF, abrir para editar, deslizar para borrar, "Nueva cotización".

- **Filtros = botones redondos** (2026-10-12): `BarraFiltros` es una sola fila siempre visible: (◎ Radio de búsqueda: dice "50 km"/zona y abre su panel) | categorías como círculos (las elegidas primero, rojas con ✓; tocar = poner/quitar) | (＋ Publicar) rojo fijo a la derecha. Ya no hay botón "Categorías" ni pastillas de filtros puestos; las subcategorías aparecen debajo si hay una sola categoría. En OkMarket, OkServicios, Encontrar y Notificaciones (sin radio ni publicar). `altoFila` = 84.
- **Comunidad como la maqueta**: pastillas [🔥 Lo más buscado] [📌 Fijados] [👤 @fernando ⊗] [🔍] ›; tocar las dos primeras muestra/esconde su franja; "Lo más buscado" = tarjetas foto + precio. La lupa abre una nube flotante (con piquito, sale de la pastilla) con campo y sugerencias de @personas; cada búsqueda queda como pastilla con ⊗; el contador x/n ▲▼ flota sobre el chat. Burbujas estilo WhatsApp: nombre de color por persona dentro de la burbuja (mismo tamaño que el texto, 14,5–15,5), hora abajo a la derecha con ⌄ para el menú, cita con barra y nombre del color de su autor. Modo oscuro: burbujas 0xFF2F323A con borde y fondo pixel más tenue.

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

### Ajustes 13-oct
- **Fotos**: el sello "OK Venta App" va en el fondo gris, detrás del producto (ya no hay logo encima). Producto al 86 % y centrado. `routers/fotos_estilo.py` pasa solas todas las fotos existentes al estilo nuevo (90 s después de arrancar, idempotente vía tabla `fotos_rehechas`; `FOTOS_ESTILO_AUTO=0` lo apaga; estado en `/admin/fotos/rehacer/estado?token=`).
- **Denuncias en Comunidad**: denunciar tapa el mensaje para todos (`censurado`), el servidor ya no entrega su contenido; el equipo lo ve en `/admin/comunidad/censurados` y puede restaurarlo.
- **Lo más buscado**: top 10 por vistas (empate: el que llegó primero a esas vistas), con llamita animada y el puesto.
- **Instalación**: el botón 🔧 del detalle solo aparece si el producto requiere instalación; abre el aviso flotante (cotizar con el vendedor / elegir a otra persona en OkServicios).
- **Filtros redondos**: `FilaConGuia` (flechas ‹ ›, borde que se desvanece y barrita de posición); etiquetas largas se achican o van en 2 líneas.
- **Resultados en filas**: corazón, carro, instalación y compartir en círculos bajo categoría/ubicación.
- (13-oct, noche) "Electrodomésticos" se muestra como "Electrohogar" en los botones (`etiquetaCategoria`; el valor guardado no cambia). Radio → ícono radar "Cerca". Filas de botones centradas si caben. Lo más buscado sin llamas (foto en recuadro, nombre, precio en pastilla roja suave). Burbujas como la maqueta: demás blancas (gris 0xFF25272C en oscuro), OkVenta negra con sello ✓, mías verde suave (verde oscuro en oscuro); @menciones del color de la persona.

### Lote 16-oct
- **Comunidad**: `TarjetaMini` (mas_vendidos_franja.dart) para "Lo más buscado" y "Fijados" (mismo tamaño; pin montado en la esquina de la foto). Burbujas al ancho del texto: la hora va en un `Positioned` y el texto deja un hueco invisible al final (truco WhatsApp). Pastillas de filtro con `FilaConGuia(centrar: false, version: n)`.
- **Políticas de uso**: `services/moderacion.py` (reglas, normaliza leet/tildes/letras repetidas) censura al enviar (`censura_motivo = 'politica:<cat>'`, `censura_tipo` = politica|denuncia en la API) y barre los últimos 1000 al arrancar (`POST /admin/comunidad/barrer`). En la app: `politicas_comunidad_screen.dart` (aceptar la 1.ª vez, guardado en SharedPreferences `comunidad_politicas_v1`), enlace "Políticas de uso" sobre la caja de texto.
- **Stickers de Okventín**: `widgets/sticker_okventin.dart`, viajan como texto `[okventin:<tipo>]` (saludo, celebra, lentes, pensativo, llora, enojado); el bot no responde a stickers ni censurados.
- **OkServicios**: mismas columnas que OkMarket (`mkt_columnas` compartido vía `VistaServicios`). Detalle de servicio: ayuda/favorito/compartir arriba y barra fija "Cotizar" (+ Llamar).
- **Encontrar**: lleva el encabezado de la app (logo / Okventín oscuro); pin de servicio con el título en miniatura.
- **Mi OkVenta**: dirección principal en el encabezado (pin, etiqueta, calle y comuna, lápiz → Mis direcciones).
- **Órdenes**: `routers/ordenes_extra.py` → `POST /ordenes/{id}/cancelar_compra` (solo comprador, solo pendiente_pago/pago_confirmado, solo 60 min desde created_at; reembolsa y repone stock) y `GET /ordenes/{id}/pago` (medio de pago desde MP cacheado en `mp_medio_pago`, pagado/abonado en, estado del abono). App: `widgets/orden_acciones.dart` (BotonCancelarOrden con cuenta atrás, Ver pago con banco/cuenta de Mi cuenta, Compartir: chat privado como `[comprobante]{json}` → `TarjetaComprobante`, o PDF A6 con Okventín por WhatsApp). Tarjetas de órdenes compactas.

### Okventín de oficio (servicios)
- `backend/assets/okventin/base.png` (figura genérica, fondo quitado) + `items/*.png` (54 accesorios recortados de la plantilla). `services/okventin_servicio.py`: `elegir_kit(titulo, categoria, desc)` por palabras → 24 oficios (cabeza, mano, suelo); `componer_kit` arma la figura (herramienta delante y el guante repintado encima para que la "agarre"); `ruta_imagen(kit, 'jpg'|'png')` cachea en UPLOADS_DIR/okventin/<kit>_v<VERSION>. Al arrancar se generan todas en segundo plano.
- Cada servicio trae `okventin_kit`, `okventin_foto` (estudio, para avisos sin foto) y `okventin_sello` (PNG transparente). Columna `servicios.okventin_kit` = override manual (`POST /admin/servicios/{id}/okventin?kit=&token=`). Imágenes en `GET /okventin/servicio/<kit>.jpg|png`.
- Para cambiar los dibujos: reemplazar los PNG de items/ y subir `VERSION`. El sello (`okventin_sello`) es Okventín dentro de `marco.png` (aro rojo con estrellas) sobre #F2F2F7 con sombra suave.
- Zonas: `RegionesChile.nombres` incluye Argentina, Perú y Bolivia (con ciudades de referencia), así se filtran y encuadran en Encontrar y OkMarket.
- App: `widgets/okventin_servicio.dart` (OkventinServicio.foto / SelloOkventin) en tarjetas, filas, detalle y Encontrar.
- Figuras finales por oficio en `backend/assets/okventin/oficios/<kit>.png` (20, del diseño "OK Venta y Servicios"); `figura(kit)` las usa y solo arma con base+accesorios si falta alguna (mudanza/delivery→transporte, refrigeracion→electrodomesticos, celulares→computacion). Sombra difuminada (`con_sombra`) en la foto de estudio y en el sello. VERSION=3.

### Mapas con CARTO
- `lib/services/mapas_config.dart`: `MapasConfig.capa()` es el fondo de TODOS los FlutterMap. Con `--dart-define=CARTO_KEY=...` (secreto de GitHub `CARTO_KEY`, lo pasa el workflow) usa CARTO raster: día `voyager`, noche `dark_all` (Dark Matter), según ThemeService; gratis comercial hasta 1M cuadritos/mes. Sin clave, OSM como antes. Crédito "© CARTO © OpenStreetMap" en Encontrar. (Se descartó Google Maps y Mapbox por costo.)
- `widgets/controles_mapa.dart`: + / − y "mi ubicación" (ControlesMapa / ControlesMapa.sobre) en Encontrar, elegir dirección, mis direcciones, entrega del vendedor, seguimiento y OkDelivery. Los mapitas fijos (mapa_mini, tarjeta de compra) no los llevan. La vista inclinada (Mapbox SDK oficial) queda pendiente.
