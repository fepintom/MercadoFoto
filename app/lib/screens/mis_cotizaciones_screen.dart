import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/cotizaciones_guardadas_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'cotizacion_editor_screen.dart';

/// Mis cotizaciones: las que hiciste en este teléfono (borradores y
/// enviadas) con su PDF. Duran 30 días y se borran solas; el aviso de arriba
/// queda siempre visible.
class MisCotizacionesScreen extends StatefulWidget {
  const MisCotizacionesScreen({super.key});

  @override
  State<MisCotizacionesScreen> createState() => _MisCotizacionesScreenState();
}

class _MisCotizacionesScreenState extends State<MisCotizacionesScreen> {
  @override
  void initState() {
    super.initState();
    CotizacionesGuardadasService.cargar();
  }

  double _total(Map<String, dynamic> d) {
    final items = (d['items'] as List? ?? const []);
    final sub = items.fold<double>(
        0,
        (a, i) =>
            a +
            (((i as Map)['precio'] as num?)?.toDouble() ?? 0) *
                ((i['cantidad'] as num?)?.toDouble() ?? 1));
    final desc = ((d['descuento'] as num?)?.toDouble() ?? 0).clamp(0, sub).toDouble();
    return sub - desc + ((d['impuestos'] as num?)?.toDouble() ?? 0);
  }

  Future<void> _abrir(CotizacionGuardada c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CotizacionEditorScreen(existente: c)),
    );
    CotizacionesGuardadasService.cargar();
  }

  Future<void> _compartir(CotizacionGuardada c) async {
    final p = c.pdfPath;
    if (p == null || !File(p).existsSync()) {
      _abrir(c);
      return;
    }
    await Printing.sharePdf(
        bytes: await File(p).readAsBytes(),
        filename: 'Cotizacion_OK_Venta_${c.numero.toString().padLeft(4, '0')}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text('Mis cotizaciones',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CotizacionEditorScreen()),
          );
          CotizacionesGuardadasService.cargar();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva cotización'),
      ),
      body: Column(children: [
        // Aviso permanente: duran 30 días
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC56B)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, color: Color(0xFFB26A00)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Las cotizaciones se guardan en este teléfono durante '
                  '$kDiasCotizacionGuardada días y luego se borran solas. '
                  'Si necesitas conservarlas, compártelas o descarga el PDF.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Color(0xFF5C3A00),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<CotizacionGuardada>>(
            valueListenable: CotizacionesGuardadasService.lista,
            builder: (context, lista, _) {
              if (lista.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/images/okventin_servicios.png',
                          height: 120),
                      const SizedBox(height: 12),
                      Text('Aún no tienes cotizaciones',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Crea una con "Nueva cotización" o desde el chat de tu servicio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textPrimary)),
                    ]),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = lista[i];
                  final d = c.datos;
                  final enviada = c.estado == 'enviada';
                  return Dismissible(
                    key: ValueKey(c.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                    ),
                    onDismissed: (_) => CotizacionesGuardadasService.borrar(c.id),
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _abrir(c),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.request_quote_outlined,
                                  color: colors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'N.º ${c.numero.toString().padLeft(4, '0')} · '
                                      '${(d['cliente_nombre'] ?? '').toString().isEmpty ? 'Sin cliente' : d['cliente_nombre']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: colors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(formatPrecio(_total(d)),
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: colors.primary)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: enviada
                                            ? colors.success.withValues(alpha: 0.15)
                                            : colors.textPrimary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                          enviada ? 'Enviada' : 'Borrador',
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: enviada
                                                  ? colors.success
                                                  : colors.textPrimary)),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.timer_outlined,
                                        size: 13,
                                        color: c.diasRestantes <= 3
                                            ? colors.primary
                                            : colors.textPrimary),
                                    const SizedBox(width: 2),
                                    Text(
                                        c.diasRestantes == 0
                                            ? 'Se borra hoy'
                                            : 'Se borra en ${c.diasRestantes} d',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.diasRestantes <= 3
                                                ? colors.primary
                                                : colors.textPrimary)),
                                  ]),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Compartir PDF',
                              onPressed: () => _compartir(c),
                              icon: Icon(Icons.ios_share_rounded,
                                  color: colors.textPrimary),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
