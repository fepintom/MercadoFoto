import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_router.dart';
import '../theme/app_theme.dart';
import '../widgets/barra_filtros.dart';
import 'oferta_screen.dart';

/// Pestaña "Alertas": todas las notificaciones en pantalla completa (antes
/// era una hoja que subía hasta la mitad).
///
/// Filtros como las categorías de OkMarket: "Filtrar" despliega Compras,
/// Ventas, Preguntas y Comunidad; las elegidas quedan como pastillas rojas
/// arriba y se quitan arrastrándolas fuera. La categoría la calcula el
/// servidor (`categoria`), según el rol del usuario en la orden.
class NotificacionesScreen extends StatefulWidget {
  final int? userId;

  /// true mientras la pestaña está a la vista: al entrar recarga y marca
  /// como leídas.
  final bool activa;
  final VoidCallback? onLeidas;
  final VoidCallback? onPedirLogin;
  final VoidCallback? onIrAComunidad;

  const NotificacionesScreen({
    super.key,
    required this.userId,
    this.activa = false,
    this.onLeidas,
    this.onPedirLogin,
    this.onIrAComunidad,
  });

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

const _kCategorias = <OpcionCategoria>[
  OpcionCategoria('Compras', Icons.shopping_bag_outlined),
  OpcionCategoria('Ventas', Icons.sell_outlined),
  OpcionCategoria('Preguntas', Icons.help_outline_rounded),
  OpcionCategoria('Comunidad', Icons.groups_outlined),
];

const _kClave = {
  'Compras': 'compras',
  'Ventas': 'ventas',
  'Preguntas': 'preguntas',
  'Comunidad': 'comunidad',
};

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _cargando = true;
  bool _error = false;
  final List<String> _filtros = [];
  PanelFiltro _panel = PanelFiltro.ninguno;

  @override
  void initState() {
    super.initState();
    if (widget.activa) _cargar();
  }

  @override
  void didUpdateWidget(covariant NotificacionesScreen old) {
    super.didUpdateWidget(old);
    if ((widget.activa && !old.activa) || widget.userId != old.userId) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final uid = widget.userId;
    if (uid == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    try {
      final data = await ApiService.obtenerNotificaciones(uid);
      if (!mounted) return;
      setState(() {
        _notifs = data;
        _cargando = false;
        _error = false;
      });
      // Entrar cuenta como "visto". En esta visita siguen resaltadas (los
      // datos ya venían con leido=0); la próxima ya no.
      if (data.any((n) => n['leido'] == 0 || n['leido'] == false)) {
        await ApiService.marcarNotificacionesLeidas(uid);
      }
      widget.onLeidas?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = _notifs.isEmpty;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visibles {
    if (_filtros.isEmpty) return _notifs;
    final claves = _filtros.map((f) => _kClave[f]).toSet();
    return _notifs
        .where((n) => claves.contains((n['categoria'] ?? 'otros').toString()))
        .toList();
  }

  // ── Apariencia ──────────────────────────────────────────────────────────

  IconData _icono(Map n) {
    switch ((n['tipo'] ?? '').toString()) {
      case 'oferta':
      case 'oferta_respuesta':
        return Icons.monetization_on_outlined;
      case 'pregunta':
        return Icons.help_outline_rounded;
      case 'chat':
      case 'chat_servicio':
        return Icons.chat_bubble_outline_rounded;
      case 'interes_compra':
        return Icons.favorite_outline;
      case 'precio':
        return Icons.sell_outlined;
      case 'elegir_entrega':
      case 'servicio_pagado':
        return Icons.payments_outlined;
      case 'en_camino':
      case 'okdelivery_en_camino':
        return Icons.local_shipping_outlined;
      case 'entrega_confirmada':
      case 'entrega_reportada':
        return Icons.check_circle_outline;
      case 'disputa':
        return Icons.warning_amber_rounded;
      case 'review':
        return Icons.star_outline_rounded;
      case 'fondos_liberados':
        return Icons.account_balance_wallet_outlined;
      case 'comunidad_mencion':
        return Icons.alternate_email_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _etiqueta(Map n) {
    switch ((n['categoria'] ?? '').toString()) {
      case 'compras':
        return 'Compra';
      case 'ventas':
        return 'Venta';
      case 'preguntas':
        return 'Pregunta';
      case 'comunidad':
        return 'Comunidad';
      default:
        return '';
    }
  }

  DateTime? _fecha(Map n) {
    final f = n['fecha']?.toString();
    if (f == null || f.isEmpty) return null;
    // SQLite guarda UTC sin zona: "2026-10-07 21:03:00".
    return DateTime.tryParse('${f.replaceFirst(' ', 'T')}Z')?.toLocal() ??
        DateTime.tryParse(f)?.toLocal();
  }

  String _hace(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return '${d.day}/${d.month}';
  }

  String _grupo(DateTime? d) {
    if (d == null) return 'Anteriores';
    final hoy = DateTime.now();
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    final dia = DateTime(d.year, d.month, d.day);
    final dias = h.difference(dia).inDays;
    if (dias <= 0) return 'Hoy';
    if (dias == 1) return 'Ayer';
    if (dias < 7) return 'Esta semana';
    return 'Anteriores';
  }

  // ── Acciones ────────────────────────────────────────────────────────────

  void _abrir(Map<String, dynamic> n) {
    final tipo = (n['tipo'] ?? '').toString();
    final pubId = n['publicacion_id'];
    if (tipo.startsWith('comunidad')) {
      widget.onIrAComunidad?.call();
      return;
    }
    if (tipo == 'oferta' && pubId != null) {
      // Vista de oferta con el monto sacado del mensaje.
      final msg = (n['mensaje'] ?? '').toString();
      final match = RegExp(r'\$([\d,.]+)').firstMatch(msg);
      final montoStr =
          (match?.group(1) ?? '0').replaceAll(',', '').replaceAll('.', '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfertaScreen(
            publicacionId: pubId,
            compradorId: n['remitente_id'] ?? 0,
            monto: double.tryParse(montoStr) ?? 0.0,
            titulo: '',
            imagenUrl: '',
          ),
        ),
      );
      return;
    }
    NotificationRouter.abrir(context, n);
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) return _sinSesion();
    final noLeidas =
        _notifs.where((n) => n['leido'] == 0 || n['leido'] == false).length;

    return Container(
      color: colors.background,
      child: Column(
        children: [
          Container(
            color: colors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_rounded,
                    size: 20, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notificaciones',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary)),
                    Text(
                        noLeidas == 0
                            ? 'Estás al día'
                            : noLeidas == 1
                                ? '1 nueva'
                                : '$noLeidas nuevas',
                        style: TextStyle(
                            fontSize: 11.5, color: colors.textPrimary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                icon: Icon(Icons.refresh_rounded, color: colors.textPrimary),
                onPressed: () {
                  setState(() => _cargando = true);
                  _cargar();
                },
              ),
            ]),
          ),
          BarraFiltros(
            mostrarDistancia: false,
            etiquetaCategorias: 'Filtrar',
            radioKm: 0,
            distanciaActiva: false,
            onRadioChanged: (_) {},
            categorias: _kCategorias,
            seleccionadas: _filtros,
            onAgregarCategoria: (c) => setState(() => _filtros.add(c)),
            onQuitarCategoria: (c) => setState(() => _filtros.remove(c)),
            panel: _panel,
            onPanel: (p) => setState(() => _panel = p),
          ),
          Divider(height: 0.5, thickness: 0.5, color: colors.divider),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_cargando && _notifs.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (_error) {
      return _vacio(Icons.wifi_off_rounded, 'No pudimos cargar tus notificaciones',
          'Desliza hacia abajo para reintentar');
    }
    final lista = _visibles;
    if (lista.isEmpty) {
      return RefreshIndicator(
        color: colors.primary,
        onRefresh: _cargar,
        child: ListView(children: [
          const SizedBox(height: 80),
          _filtros.isEmpty
              ? _vacio(Icons.notifications_none_rounded, 'Sin notificaciones aún',
                  'Cuando tengas actividad, aparecerá aquí')
              : _vacio(Icons.filter_alt_off_outlined,
                  'Nada en ${_filtros.join(' y ').toLowerCase()}',
                  'Quita un filtro arrastrándolo fuera'),
        ]),
      );
    }

    // Lista con separadores por fecha.
    final filas = <Widget>[];
    String? grupoActual;
    for (final n in lista) {
      final d = _fecha(n);
      final g = _grupo(d);
      if (g != grupoActual) {
        grupoActual = g;
        filas.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(g,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
        ));
      }
      filas.add(_fila(n, d));
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: filas,
      ),
    );
  }

  Widget _fila(Map<String, dynamic> n, DateTime? d) {
    final leida = n['leido'] == 1 || n['leido'] == true;
    final etiqueta = _etiqueta(n);
    return InkWell(
      onTap: () => _abrir(n),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: leida
              ? colors.surface
              : Color.alphaBlend(
                  colors.primary.withValues(alpha: 0.06), colors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: leida
                  ? colors.divider
                  : colors.primary.withValues(alpha: 0.35),
              width: 0.6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(_icono(n), color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((n['mensaje'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          color: colors.textPrimary,
                          fontWeight:
                              leida ? FontWeight.w400 : FontWeight.w600)),
                  const SizedBox(height: 5),
                  Row(children: [
                    if (etiqueta.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: colors.textPrimary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(etiqueta,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(_hace(d),
                        style: TextStyle(
                            fontSize: 11, color: colors.textPrimary)),
                  ]),
                ],
              ),
            ),
            if (!leida)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 6),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: colors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _vacio(IconData icono, String titulo, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 56, color: colors.grayMid.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _sinSesion() {
    return Container(
      color: colors.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: colors.grayMid),
          const SizedBox(height: 20),
          Text('Inicia sesión para ver\ntus notificaciones',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.onPedirLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.textOnPrimary,
            ),
            child: const Text('Ingresar'),
          ),
        ],
      ),
    );
  }
}
