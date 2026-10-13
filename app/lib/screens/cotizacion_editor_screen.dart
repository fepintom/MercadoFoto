import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../services/api_service.dart';
import '../services/cotizacion_pdf.dart';
import '../services/cotizaciones_guardadas_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

/// Editor de cotizaciones, como la maqueta:
///
///   ‹  OK VENTA  ⋮
///   Cotización                [🖨 Imprimir]
///   N.º 0001                    12/10/2026
///   [De: empresa] [Para: cliente]
///   Detalle: ítems (✎ editar, 🗑 borrar) + Agregar ítem
///   Subtotal / Descuento / Impuestos / TOTAL / Retención / Pago inicial
///   Garantía · Condiciones (válida hasta, entrega, pago) · Observaciones
///   [Guardar borrador] [Enviar cotización]
///
/// Abierto desde el chat de un servicio ([servicioId] + [clienteId]) se
/// envía al chat (el servidor arma el PDF oficial). Abierto desde "Mis
/// cotizaciones" (sin chat) el botón principal comparte el PDF.
class CotizacionEditorScreen extends StatefulWidget {
  final CotizacionGuardada? existente;
  final int? servicioId;
  final int? proveedorId;
  final int? clienteId;
  final String empresa;
  final String clienteNombre;

  const CotizacionEditorScreen({
    super.key,
    this.existente,
    this.servicioId,
    this.proveedorId,
    this.clienteId,
    this.empresa = '',
    this.clienteNombre = '',
  });

  @override
  State<CotizacionEditorScreen> createState() => _CotizacionEditorScreenState();
}

class _CotizacionEditorScreenState extends State<CotizacionEditorScreen> {
  late String _id;
  int _numero = 0;
  late DateTime _creado;
  String _empresa = '';
  String _cliente = '';
  final List<Map<String, dynamic>> _items = [];
  double _descuento = 0;
  double _impuestos = 0;
  late DateTime _validaHasta;
  String _entrega = 'A convenir';
  String _formaPago = 'A convenir';
  final _obs = TextEditingController();
  bool _enviando = false;

  int? get _servicioId => widget.existente?.servicioId ?? widget.servicioId;
  int? get _proveedorId => widget.existente?.proveedorId ?? widget.proveedorId;
  int? get _clienteId => widget.existente?.clienteId ?? widget.clienteId;
  bool get _porChat =>
      _servicioId != null && _proveedorId != null && _clienteId != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _creado = e?.creado ?? DateTime.now();
    _id = e?.id ?? '${DateTime.now().millisecondsSinceEpoch}';
    _validaHasta = DateTime.now().add(const Duration(days: 7));
    if (e != null) {
      _numero = e.numero;
      final d = e.datos;
      _empresa = (d['empresa'] ?? '').toString();
      _cliente = (d['cliente_nombre'] ?? '').toString();
      _items.addAll((d['items'] as List? ?? const [])
          .map((x) => Map<String, dynamic>.from(x as Map)));
      _descuento = (d['descuento'] as num?)?.toDouble() ?? 0;
      _impuestos = (d['impuestos'] as num?)?.toDouble() ?? 0;
      _validaHasta =
          DateTime.tryParse(d['valida_hasta']?.toString() ?? '') ?? _validaHasta;
      _entrega = (d['entrega'] ?? 'A convenir').toString();
      _formaPago = (d['forma_pago'] ?? 'A convenir').toString();
      _obs.text = (d['observaciones'] ?? '').toString();
    } else {
      _empresa = widget.empresa;
      _cliente = widget.clienteNombre;
      CotizacionesGuardadasService.siguienteNumero().then((n) {
        if (mounted) setState(() => _numero = n);
      });
    }
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  // ── Cálculos ─────────────────────────────────────────────────────────────
  double get _subtotal => _items.fold<double>(
      0,
      (a, i) =>
          a +
          ((i['precio'] as num?)?.toDouble() ?? 0) *
              ((i['cantidad'] as num?)?.toDouble() ?? 1));
  double get _total =>
      _subtotal - _descuento.clamp(0, _subtotal).toDouble() + _impuestos;
  double get _retencion => (_total * kPctRetencionGarantia).roundToDouble();

  String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> get _datos => {
        'empresa': _empresa,
        'cliente_nombre': _cliente,
        'items': _items,
        'descuento': _descuento,
        'impuestos': _impuestos,
        'valida_hasta': _iso(_validaHasta),
        'entrega': _entrega,
        'forma_pago': _formaPago,
        'observaciones': _obs.text.trim(),
      };

  // ── Edición ──────────────────────────────────────────────────────────────
  Future<String?> _pedirTexto(String titulo, String inicial,
      {String? ayuda, TextInputType teclado = TextInputType.text}) async {
    final c = TextEditingController(text: inicial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: teclado,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: teclado == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(hintText: ayuda),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: Text('Listo', style: TextStyle(color: colors.primary))),
        ],
      ),
    );
    return r?.trim();
  }

  Future<void> _editarItem([int? indice]) async {
    final previo = indice == null ? null : _items[indice];
    final nombre = TextEditingController(text: previo?['nombre']?.toString() ?? '');
    final cantidad = TextEditingController(
        text: ((previo?['cantidad'] as num?)?.toInt() ?? 1).toString());
    final precio = TextEditingController(
        text: ((previo?['precio'] as num?)?.toInt() ?? 0) == 0
            ? ''
            : (previo!['precio'] as num).toInt().toString());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(indice == null ? 'Agregar ítem' : 'Editar ítem',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
            const SizedBox(height: 12),
            _campo('Producto o servicio', nombre, autofocus: true),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  flex: 2,
                  child: _campo('Cantidad', cantidad, numero: true)),
              const SizedBox(width: 10),
              Expanded(
                  flex: 3,
                  child: _campo('Precio unitario', precio,
                      numero: true, prefijo: '\$ ')),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar ítem'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final n = nombre.text.trim();
    final p = double.tryParse(precio.text.trim()) ?? 0;
    final c = int.tryParse(cantidad.text.trim()) ?? 1;
    if (n.isEmpty || p <= 0) {
      _aviso('Falta el nombre o el precio del ítem');
      return;
    }
    setState(() {
      final it = {'nombre': n, 'cantidad': c < 1 ? 1 : c, 'precio': p};
      if (indice == null) {
        _items.add(it);
      } else {
        _items[indice] = it;
      }
    });
  }

  Widget _campo(String etiqueta, TextEditingController c,
      {bool numero = false, String? prefijo, bool autofocus = false}) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      keyboardType: numero ? TextInputType.number : TextInputType.text,
      inputFormatters: numero ? [FilteringTextInputFormatter.digitsOnly] : null,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixText: prefijo,
        filled: true,
        fillColor: colors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  void _aviso(String t) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(t), behavior: SnackBarBehavior.floating));
  }

  // ── Acciones ─────────────────────────────────────────────────────────────
  bool _validar() {
    if (_items.isEmpty) {
      _aviso('Agrega al menos un ítem');
      return false;
    }
    if (_total <= 0) {
      _aviso('El total debe ser mayor a \$0');
      return false;
    }
    return true;
  }

  Future<CotizacionGuardada> _guardarLocal(String estado) async {
    final pdf = await CotizacionPdf.generar(_datos,
        numero: _numero, emision: _creado);
    return CotizacionesGuardadasService.guardar(
      CotizacionGuardada(
        id: _id,
        numero: _numero,
        creado: _creado,
        estado: estado,
        datos: _datos,
        servicioId: _servicioId,
        proveedorId: _proveedorId,
        clienteId: _clienteId,
      ),
      pdf: pdf,
    );
  }

  Future<void> _guardarBorrador() async {
    await _guardarLocal('borrador');
    _aviso('Guardada en Mis cotizaciones (se borra en 30 días)');
  }

  Future<void> _imprimir() async {
    if (!_validar()) return;
    await Printing.layoutPdf(
      name: 'Cotizacion_OK_Venta_${_numero.toString().padLeft(4, '0')}.pdf',
      onLayout: (_) =>
          CotizacionPdf.generar(_datos, numero: _numero, emision: _creado),
    );
  }

  Future<void> _compartir() async {
    if (!_validar()) return;
    final c = await _guardarLocal(widget.existente?.estado ?? 'borrador');
    final bytes =
        await CotizacionPdf.generar(_datos, numero: _numero, emision: _creado);
    await Printing.sharePdf(
        bytes: bytes,
        filename: 'Cotizacion_OK_Venta_${c.numero.toString().padLeft(4, '0')}.pdf');
  }

  Future<void> _enviar() async {
    if (!_validar()) return;
    if (!_porChat) return _compartir();
    setState(() => _enviando = true);
    try {
      await ApiService.enviarCotizacion(
        servicioId: _servicioId!,
        proveedorId: _proveedorId!,
        clienteId: _clienteId!,
        servicioCotizado: _items.map((i) => i['nombre']).join(', '),
        monto: _total,
        detalle: _obs.text.trim(),
        empresa: _empresa,
        datos: jsonEncode(_datos),
      );
      await _guardarLocal('enviada');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _aviso('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        centerTitle: true,
        title: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: 'OK',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: colors.primary)),
            TextSpan(
                text: ' VENTA',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary)),
          ]),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.textPrimary),
            onSelected: (v) {
              if (v == 'guardar') _guardarBorrador();
              if (v == 'compartir') _compartir();
              if (v == 'imprimir') _imprimir();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'guardar', child: Text('Guardar en Mis cotizaciones')),
              PopupMenuItem(value: 'compartir', child: Text('Compartir PDF')),
              PopupMenuItem(value: 'imprimir', child: Text('Imprimir')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Row(children: [
                  Expanded(
                    child: Text('Cotización',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _imprimir,
                    icon: Icon(Icons.print_outlined,
                        size: 18, color: colors.textPrimary),
                    label: Text('Imprimir',
                        style: TextStyle(color: colors.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Text('N.º ${_numero.toString().padLeft(4, '0')}',
                      style: TextStyle(color: colors.textPrimary)),
                  const Spacer(),
                  Text(_dmy(_creado),
                      style: TextStyle(color: colors.textPrimary)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _cajaPersona('De', Icons.storefront_outlined,
                          _empresa.isEmpty ? 'Nombre o empresa' : _empresa,
                          () async {
                    final v = await _pedirTexto('¿Quién cotiza?', _empresa,
                        ayuda: 'Tu nombre o el de tu empresa');
                    if (v != null) setState(() => _empresa = v);
                  })),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _cajaPersona('Para', Icons.person_outline_rounded,
                          _cliente.isEmpty ? 'Nombre del cliente' : _cliente,
                          () async {
                    final v = await _pedirTexto('¿Para quién?', _cliente,
                        ayuda: 'Nombre del cliente');
                    if (v != null) setState(() => _cliente = v);
                  })),
                ]),
                const SizedBox(height: 12),
                _tarjeta([
                  Text('Detalle',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _items.length; i++) _filaItem(i),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _editarItem(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Agregar ítem'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colors.divider),
                  const SizedBox(height: 10),
                  _filaMonto('Subtotal', formatPrecio(_subtotal)),
                  _filaMonto(
                      'Descuento',
                      '${_descuento > 0 ? '-' : ''}${formatPrecio(_descuento)}',
                      onTap: () async {
                    final v = await _pedirTexto('Descuento (\$)',
                        _descuento == 0 ? '' : _descuento.toInt().toString(),
                        teclado: TextInputType.number);
                    if (v != null) {
                      setState(() => _descuento = double.tryParse(v) ?? 0);
                    }
                  }),
                  _filaMonto('Impuestos', formatPrecio(_impuestos),
                      ayuda: 'Según corresponda', onTap: () async {
                    final v = await _pedirTexto('Impuestos (\$)',
                        _impuestos == 0 ? '' : _impuestos.toInt().toString(),
                        teclado: TextInputType.number);
                    if (v != null) {
                      setState(() => _impuestos = double.tryParse(v) ?? 0);
                    }
                  }),
                  Divider(height: 18, color: colors.divider),
                  Row(children: [
                    Text('Total',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary)),
                    const Spacer(),
                    Text(formatPrecio(_total),
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary)),
                  ]),
                  Divider(height: 18, color: colors.divider),
                  Row(children: [
                    Text('Retención (',
                        style: TextStyle(color: colors.textPrimary)),
                    GestureDetector(
                      onTap: _verDetalleRetencion,
                      child: Text('ver detalle',
                          style: TextStyle(
                              color: colors.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: colors.primary)),
                    ),
                    Text(')', style: TextStyle(color: colors.textPrimary)),
                    const Spacer(),
                    Text(formatPrecio(_retencion),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                  ]),
                  const SizedBox(height: 6),
                  _filaMonto('Pago inicial al prestador',
                      formatPrecio(_total - _retencion)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.verified_user_outlined,
                          color: colors.textPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'Garantía del servicio: la retención se libera al prestador '
                            'cuando el cliente confirma que está todo bien, o '
                            'automáticamente a los $kDiasRetencionGarantia días si no '
                            'reporta un problema.',
                            style: TextStyle(
                                fontSize: 12, color: colors.textPrimary)),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                _tarjeta([
                  Text('Condiciones',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                  _filaCondicion(Icons.calendar_today_outlined, 'Válida hasta:',
                      _dmy(_validaHasta), () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate: _validaHasta,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (f != null) setState(() => _validaHasta = f);
                  }),
                  _filaCondicion(Icons.local_shipping_outlined,
                      'Entrega o ejecución:', _entrega, () async {
                    final v = await _pedirTexto('Entrega o ejecución', _entrega,
                        ayuda: 'Ej: Sábado 18/10, 10:00');
                    if (v != null && v.isNotEmpty) setState(() => _entrega = v);
                  }),
                  _filaCondicion(Icons.credit_card_outlined, 'Forma de pago:',
                      _formaPago, () async {
                    final v = await _pedirTexto('Forma de pago', _formaPago,
                        ayuda: 'Ej: Pago protegido OkVenta');
                    if (v != null && v.isNotEmpty) setState(() => _formaPago = v);
                  }),
                ]),
                const SizedBox(height: 12),
                _tarjeta([
                  Text('Observaciones',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _obs,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Agrega detalles importantes...',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.divider)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.divider)),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('Valores expresados en CLP',
                    style: TextStyle(fontSize: 11, color: colors.textPrimary)),
              ],
            ),
          ),
          Container(
            color: colors.background,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _guardarBorrador,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar borrador',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_porChat ? 'Enviar cotización' : 'Compartir PDF',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _verDetalleRetencion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retención de garantía'),
        content: Text(
            'Del total, el ${(kPctRetencionGarantia * 100).round()} % '
            '(${formatPrecio(_retencion)}) queda retenido por OkVenta como '
            'garantía. Se libera al prestador cuando el cliente confirma que el '
            'servicio está conforme, o automáticamente a los '
            '$kDiasRetencionGarantia días si no reporta un problema.\n\n'
            'Pago inicial al prestador: ${formatPrecio(_total - _retencion)}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Entendido', style: TextStyle(color: colors.primary))),
        ],
      ),
    );
  }

  Widget _tarjeta(List<Widget> hijos) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider, width: 0.6),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: hijos),
      );

  Widget _cajaPersona(
      String rotulo, IconData icono, String texto, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo,
                style: TextStyle(fontSize: 12, color: colors.textPrimary)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(icono, size: 20, color: colors.textPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(texto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14, color: colors.textPrimary)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _filaItem(int i) {
    final it = _items[i];
    final cant = (it['cantidad'] as num?)?.toInt() ?? 1;
    final precio = (it['precio'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider, width: 0.6))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _editarItem(i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(it['nombre'].toString(),
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined,
                        size: 16, color: colors.textPrimary),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                      cant > 1
                          ? 'Cantidad: $cant · ${formatPrecio(precio)} c/u'
                          : 'Cantidad: $cant',
                      style: TextStyle(
                          fontSize: 12.5, color: colors.textPrimary)),
                ],
              ),
            ),
          ),
          Text(formatPrecio(precio * cant),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded,
                size: 21, color: colors.textPrimary),
            onPressed: () => setState(() => _items.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Widget _filaMonto(String rotulo, String valor,
      {String? ayuda, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(rotulo,
                    style:
                        TextStyle(fontSize: 14, color: colors.textPrimary)),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined,
                      size: 14, color: colors.textPrimary),
                ],
              ]),
              if (ayuda != null)
                Text(ayuda,
                    style:
                        TextStyle(fontSize: 11.5, color: colors.textPrimary)),
            ],
          ),
          const Spacer(),
          Text(valor,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
        ]),
      ),
    );
  }

  Widget _filaCondicion(
      IconData icono, String rotulo, String valor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            border:
                Border(top: BorderSide(color: colors.divider, width: 0.6))),
        child: Row(children: [
          Icon(icono, size: 20, color: colors.textPrimary),
          const SizedBox(width: 12),
          Text(rotulo, style: TextStyle(color: colors.textPrimary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textPrimary)),
          ),
        ]),
      ),
    );
  }
}
