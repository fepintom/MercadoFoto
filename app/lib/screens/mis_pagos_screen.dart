import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/net_image.dart';

/// Mis pagos: la bitácora de lo que el usuario ha recibido como vendedor o
/// proveedor.
///
/// Arriba, cuánto tiene liberado (ya le corresponde), cuánto retenido (el
/// comprador pagó, pero la plata espera a que confirme la recepción o a que
/// pase la garantía) y cuánto en disputa. Abajo, cada venta con su monto,
/// la comisión de OkVenta, el neto y los hitos de la bitácora.
class MisPagosScreen extends StatefulWidget {
  const MisPagosScreen({super.key});

  @override
  State<MisPagosScreen> createState() => _MisPagosScreenState();
}

class _MisPagosScreenState extends State<MisPagosScreen> {
  Map<String, dynamic>? _data;
  bool _cargando = true;
  bool _error = false;
  bool _sinSesion = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    final uid = await SessionService.obtenerUser();
    if (uid == null) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _sinSesion = true;
        });
      }
      return;
    }
    try {
      final d = await ApiService.obtenerMisPagos(uid);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = d == null;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text('Mis pagos',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (_sinSesion) {
      return _mensaje(Icons.lock_outline_rounded,
          'Inicia sesión para ver tus pagos');
    }
    if (_error || _data == null) {
      return _mensaje(Icons.wifi_off_rounded, 'No se pudieron cargar tus pagos',
          reintentar: true);
    }
    final resumen = Map<String, dynamic>.from(_data!['resumen'] ?? {});
    final movs = List<Map<String, dynamic>>.from(_data!['movimientos'] ?? []);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _tarjetaResumen(resumen),
          const SizedBox(height: 14),
          if (movs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 52, color: colors.textPrimary.withValues(alpha: 0.4)),
                const SizedBox(height: 10),
                Text('Aún no has recibido pagos',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text('Cuando alguien te compre, verás aquí cada pago.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              ]),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Movimientos',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary)),
            ),
            for (final m in movs) ...[
              _tarjetaMovimiento(m),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _mensaje(IconData icono, String texto, {bool reintentar = false}) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 48, color: colors.primary),
        const SizedBox(height: 10),
        Text(texto,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: colors.textPrimary)),
        if (reintentar)
          TextButton(
              onPressed: _cargar,
              child:
                  Text('Reintentar', style: TextStyle(color: colors.primary))),
      ]),
    );
  }

  Widget _tarjetaResumen(Map<String, dynamic> r) {
    Widget dato(String titulo, dynamic monto, Color color, String ayuda) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatPrecio(monto),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            ),
            Text(ayuda,
                style: TextStyle(fontSize: 10, color: colors.textPrimary)),
          ],
        ),
      );
    }

    final disputa = (r['en_disputa'] as num?) ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            dato('Liberado', r['liberado'], colors.success, 'Ya te corresponde'),
            const SizedBox(width: 10),
            dato('Retenido', r['retenido'], colors.textPrimary,
                'Espera confirmación'),
          ]),
          if (disputa > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              dato('En disputa', disputa, colors.primary, 'Congelado por reclamo'),
            ]),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 8),
          Text(
            'Comisiones de OkVenta: ${formatPrecio(r['comisiones'])}. '
            'Los montos son netos: ya tienen descontada la comisión.',
            style: TextStyle(fontSize: 11, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  static const _estados = <String, (String, IconData)>{
    'liberado': ('Liberado', Icons.check_circle_rounded),
    'parcial': ('80% liberado', Icons.timelapse_rounded),
    'retenido': ('Retenido', Icons.lock_clock_outlined),
    'en_disputa': ('En disputa', Icons.report_gmailerrorred_rounded),
    'reembolsado': ('Reembolsado', Icons.undo_rounded),
  };

  Color _colorEstado(String e) {
    switch (e) {
      case 'liberado':
        return colors.success;
      case 'en_disputa':
      case 'reembolsado':
        return colors.primary;
      default:
        return colors.textPrimary;
    }
  }

  Widget _tarjetaMovimiento(Map<String, dynamic> m) {
    final estado = (m['estado_pago'] ?? 'retenido').toString();
    final (etiqueta, icono) =
        _estados[estado] ?? ('Retenido', Icons.lock_clock_outlined);
    final color = _colorEstado(estado);
    final foto = (m['foto'] ?? '').toString();
    final hitos = List<Map<String, dynamic>>.from(m['hitos'] ?? []);
    final esServicio = m['tipo'] == 'servicio';

    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
          color: colors.background, borderRadius: BorderRadius.circular(8)),
      child: Icon(
          esServicio ? Icons.handyman_outlined : Icons.shopping_cart_outlined,
          size: 20,
          color: colors.textPrimary),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Theme(
        // Sin las líneas que ExpansionTile dibuja al abrirse.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: foto.isEmpty
              ? fallback
              : NetImage(
                  foto.startsWith('http') ? foto : '${ApiService.baseUrl}$foto',
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(8),
                  errorWidget: fallback),
          title: Text((m['titulo'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Icon(icono, size: 13, color: color),
              const SizedBox(width: 3),
              Text(etiqueta,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              if (m['es_test'] == true) ...[
                const SizedBox(width: 6),
                Text('· prueba',
                    style: TextStyle(fontSize: 11, color: colors.textPrimary)),
              ],
              const Spacer(),
              Text(_fecha(m['fecha']),
                  style: TextStyle(fontSize: 11, color: colors.textPrimary)),
            ]),
          ),
          trailing: Text(formatPrecio(m['neto']),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
          children: [
            _linea('Pagó el comprador', formatPrecio(m['monto'])),
            _linea('Comisión OkVenta', '- ${formatPrecio(m['comision'])}'),
            _linea('Neto para ti', formatPrecio(m['neto']), fuerte: true),
            if (estado == 'parcial') ...[
              _linea('Liberado', formatPrecio(m['liberado'])),
              _linea('Retenido por garantía (30 días)',
                  formatPrecio(m['retenido'])),
            ],
            if ((m['comprador'] ?? '').toString().isNotEmpty)
              _linea('Comprador', m['comprador'].toString()),
            if (hitos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Bitácora',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
              ),
              const SizedBox(height: 4),
              for (final h in hitos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text((h['texto'] ?? '').toString(),
                            style: TextStyle(
                                fontSize: 12, color: colors.textPrimary)),
                      ),
                      Text(_fecha(h['fecha'], conHora: true),
                          style: TextStyle(
                              fontSize: 11, color: colors.textPrimary)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linea(String a, String b, {bool fuerte = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Expanded(
          child: Text(a,
              style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
        ),
        Text(b,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
                color: colors.textPrimary)),
      ]),
    );
  }

  /// El servidor guarda en UTC (CURRENT_TIMESTAMP de SQLite).
  static String _fecha(dynamic ts, {bool conHora = false}) {
    if (ts == null) return '';
    final txt = ts.toString().replaceFirst(' ', 'T');
    final d = DateTime.tryParse(txt.endsWith('Z') || txt.contains('+')
        ? txt
        : '${txt}Z');
    if (d == null) return '';
    final l = d.toLocal();
    final f = '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/${l.year}';
    if (!conHora) return f;
    return '$f ${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}
