import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'chat_servicio_screen.dart';
import '../widgets/net_image.dart';
class ServicioDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> servicio;

  const ServicioDetalleScreen({super.key, required this.servicio});

  @override
  State<ServicioDetalleScreen> createState() =>
      _ServicioDetalleScreenState();
}

class _ServicioDetalleScreenState extends State<ServicioDetalleScreen> {
  late Map<String, dynamic> _srv;
  int? _miUserId;
  int _miRating = 0;
  bool _enviandoRating = false;
  bool _pagando = false;

  @override
  void initState() {
    super.initState();
    _srv = Map<String, dynamic>.from(widget.servicio);
    _cargarUserId();
  }

  Future<void> _cargarUserId() async {
    _miUserId = await SessionService.obtenerUser();
    if (mounted) setState(() {});
  }

  Future<void> _valorar(int estrellas) async {
    if (_miUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes iniciar sesión para calificar')));
      return;
    }
    setState(() { _miRating = estrellas; _enviandoRating = true; });
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/servicios/${_srv['id']}/valorar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _miUserId, 'estrellas': estrellas}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _srv['rating']           = data['rating'];
          _srv['num_valoraciones'] = data['num_valoraciones'];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _enviandoRating = false);
    }
  }

  String _limpiarTelefono(String raw) {
    var num = raw.replaceAll(RegExp(r'\D'), '');
    // Quitar 56 inicial para evitar doble prefijo (+5656XXXXXXX)
    if (num.startsWith('56') && num.length > 9) num = num.substring(2);
    return num;
  }

  /// Abre el chat del servicio. Es la vía de contacto principal: deja la
  /// conversación dentro de la app, permite cotizar y no expone datos
  /// personales de ninguna de las dos partes.
  void _contactar() {
    _registrarContacto('chat');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatServicioScreen(
          servicioId: _srv['id'] as int,
          proveedorId: _srv['user_id'] as int,
          tituloServicio: (_srv['titulo'] ?? 'Servicio').toString(),
          nombreProveedor: (_srv['nombre'] ?? '').toString(),
        ),
      ),
    );
  }

  /// Llama al proveedor SIN mostrar su número.
  ///
  /// La app nunca lo escribe en pantalla: la hoja solo dice a qué servicio
  /// se está llamando. Aun así hay un límite honesto — cuando el marcador
  /// del teléfono toma el control, el sistema operativo muestra el número
  /// que se está marcando, y eso no lo controla la app. Para que quede
  /// oculto de punta a punta hace falta un número intermediario (un proxy
  /// tipo Twilio), que es una integración aparte; el aviso al pie lo deja
  /// claro en vez de prometer algo que no se cumple.
  Future<void> _llamar() async {
    final num = _limpiarTelefono(
        (_srv['telefono'] ?? _srv['whatsapp'] ?? '').toString());
    if (num.isEmpty) return;

    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.call, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contactando a servicio de:',
                        style:
                            TextStyle(fontSize: 12.5, color: colors.grayMid)),
                    const SizedBox(height: 2),
                    Text((_srv['titulo'] ?? 'Servicio').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              'Por tu privacidad y la del proveedor, OkVenta no muestra el '
              'número. Tu teléfono sí lo marcará para conectar la llamada.',
              style: TextStyle(
                  fontSize: 12, color: colors.grayMid, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Llamar ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.carbon,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;
    _registrarContacto('llamada');
    final uri = Uri.parse('tel:+56$num');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada')));
      }
    }
  }

  void _registrarContacto(String tipo) {
    ApiService.registrarContactoServicio(
      _srv['id'] as int,
      _miUserId,
      tipo,
      '',
    ).catchError((_) {});  // silencioso, no interrumpir UX
  }

  Future<void> _pagarServicio() async {
    if (_miUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes iniciar sesión para contratar el servicio')),
      );
      return;
    }
    if (_pagando) return;

    final servicioId = _srv['id'] as int? ?? 0;
    final vendedorId = _srv['user_id'] as int? ?? 0;
    final titulo = _srv['titulo'] as String? ?? 'Servicio';
    final monto = (_srv['valor'] as num?)?.toDouble() ?? 0;

    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Este servicio no tiene un precio definido'),
            backgroundColor: colors.carbon),
      );
      return;
    }

    setState(() => _pagando = true);
    try {
      final data = await ApiService.crearPreferencia(
        compradorId: _miUserId!,
        vendedorId: vendedorId,
        tipo: 'servicio',
        titulo: titulo,
        monto: monto,
        servicioId: servicioId,
      );

      // ── Modo prueba: el pago ya quedó simulado como aprobado en el backend.
      if (data['test_mode'] == true) {
        if (!mounted) return;
        await _mostrarConfirmacionTestMode();
        return;
      }

      final initPoint = data['init_point'] as String? ??
          data['sandbox_init_point'] as String? ??
          '';

      if (initPoint.isEmpty) throw Exception('No se obtuvo el link de pago');

      final uri = Uri.parse(initPoint);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el navegador');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar el pago: $e'),
          backgroundColor: colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  // ── Confirmación visual de pago simulado (modo prueba) ───────────────────
  Future<void> _mostrarConfirmacionTestMode() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.science_rounded, color: colors.warning),
            SizedBox(width: 8),
            Expanded(child: Text('Pago simulado (modo prueba)')),
          ],
        ),
        content: const Text(
          'No se realizó ningún cobro real. El prestador del servicio ya fue '
          'notificado como si el pago hubiera sido aprobado, para que pruebes '
          'el flujo completo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre     = '${_srv['nombre'] ?? ''} ${_srv['apellido'] ?? ''}'.trim();
    final fotoUrl    = _srv['foto_url'] as String? ?? '';
    final titulo     = _srv['titulo'] as String? ?? '';
    final descripcion = _srv['descripcion'] as String? ?? '';
    final comunas    = _srv['comunas'] as String? ?? '';
    final valor      = (_srv['valor'] as num?)?.toDouble() ?? 0;
    final modalidad  = _srv['modalidad'] as String? ?? 'servicio';
    final fotos      = _srv['fotos'] as List? ?? [];
    final verificado = _srv['certificado_verificado'] as bool? ?? false;
    final rating     = (_srv['rating'] as num?)?.toDouble() ?? 0.0;
    final numVal     = _srv['num_valoraciones'] as int? ?? 0;
    final tipo       = _srv['tipo'] as String? ?? 'ofrezco';
    final tieneTelefono =
        (_srv['telefono'] ?? _srv['whatsapp'] ?? '').toString().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar con imagen/foto ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: colors.surface,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios,
                  size: 18, color: colors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Okventin servicios: solo en modo oscuro
              ValueListenableBuilder<bool>(
                valueListenable: ThemeService.isDarkNotifier,
                builder: (_, isDark, __) {
                  if (!isDark) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Image.asset(
                          'assets/images/okventin_servicios.png',
                          width: 57,
                          height: 57),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: fotos.isNotEmpty
                  ? NetImage(
                      '${ApiService.baseUrl}${fotos.first}',
                      fit: BoxFit.cover,
                    )
                  : _fotoPlaceholder(fotoUrl, nombre),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Perfil + badge ──────────────────────────────────────
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.primary.withOpacity(0.15),
                        backgroundImage: fotoUrl.isNotEmpty
                            ? NetworkImage(
                                '${ApiService.baseUrl}$fotoUrl')
                            : null,
                        child: fotoUrl.isEmpty
                            ? Text(
                                nombre.isNotEmpty
                                    ? nombre[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: colors.textPrimary)),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tipo == 'ofrezco'
                                        ? colors.primary.withOpacity(0.1)
                                        : colors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tipo == 'ofrezco' ? 'Ofrece' : 'Busca',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: tipo == 'ofrezco'
                                            ? colors.primary
                                            : colors.warning),
                                  ),
                                ),
                                if (verificado) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified,
                                            color: Colors.green, size: 12),
                                        SizedBox(width: 3),
                                        Text('Profesional Certificado',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Título ──────────────────────────────────────────────
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),

                  const SizedBox(height: 16),

                  // ── Precio ──────────────────────────────────────────────
                  if (valor > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: colors.primary.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined,
                              color: colors.primary, size: 22),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: colors.primary),
                              ),
                              Text(
                                'por $modalidad',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colors.grayMid),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ── Descripción ─────────────────────────────────────────
                  if (descripcion.isNotEmpty) ...[
                    _seccion('Detalle del servicio', descripcion),
                    const SizedBox(height: 16),
                  ],

                  // ── Comunas ─────────────────────────────────────────────
                  if (comunas.isNotEmpty) ...[
                    _seccionIcono(
                      Icons.location_on_outlined,
                      'Comunas de cobertura',
                      comunas,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Fotos adicionales ───────────────────────────────────
                  if (fotos.length > 1) ...[
                    Text('Fotos',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fotos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => NetImage(
                          '${ApiService.baseUrl}${fotos[i]}',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Calificación ────────────────────────────────────────
                  _buildCalificacion(rating, numVal),

                  const SizedBox(height: 24),

                  // ── Botones de contacto ─────────────────────────────────
                  Text('Contactar',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  const SizedBox(height: 12),

                  // Contactar abre el chat: ahí se conversa y se cotiza,
                  // sin exponer el teléfono de ninguna de las dos partes.
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _contactar,
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 18),
                          label: const Text('Contactar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (tieneTelefono) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _llamar,
                            icon: const Icon(Icons.call, size: 18),
                            label: const Text('Llamar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.carbon,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Pagar servicio con MercadoPago ──────────────────────
                  if (tipo == 'ofrezco' && valor > 0)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pagando ? null : _pagarServicio,
                        icon: _pagando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.credit_card, size: 20),
                        label: Text(
                            _pagando ? 'Procesando...' : 'Contratar y pagar',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009EE3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalificacion(double rating, int numVal) {
    final esPropio = _miUserId != null && _miUserId == _srv['user_id'];
    final puedeValorar = _miUserId != null && !esPropio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Calificación',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const Spacer(),
              if (numVal > 0) ...[
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, color: Colors.amber, size: 22),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (numVal == 0) ...[
            // Sin calificaciones aún
            Row(
              children: [
                Icon(Icons.star_border_rounded,
                    size: 16, color: colors.grayMid),
                SizedBox(width: 6),
                Text(
                  'Este profesional aún no ha sido calificado',
                  style: TextStyle(fontSize: 13, color: colors.grayMid),
                ),
              ],
            ),
            if (puedeValorar) ...[
              const SizedBox(height: 12),
              Text(
                'Califica este servicio si lo has contratado:',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              _estrellasInteractivas(rating),
            ],
          ] else ...[
            Text('$numVal valoración${numVal == 1 ? '' : 'es'}',
                style: TextStyle(
                    fontSize: 12, color: colors.grayMid)),
            if (puedeValorar) ...[
              const SizedBox(height: 12),
              Text(
                'Tu calificación:',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              _estrellasInteractivas(rating),
            ],
          ],

          if (_enviandoRating)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(color: colors.primary),
            ),
        ],
      ),
    );
  }

  Widget _estrellasInteractivas(double rating) {
    return Row(
      children: List.generate(5, (i) {
        final sel = i < (_miRating > 0 ? _miRating : rating.round());
        return GestureDetector(
          onTap: () => _valorar(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              sel ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 32,
            ),
          ),
        );
      }),
    );
  }

  Widget _fotoPlaceholder(String fotoUrl, String nombre) {
    if (fotoUrl.isNotEmpty) {
      return NetImage('${ApiService.baseUrl}$fotoUrl', fit: BoxFit.cover);
    }
    return _colorPlaceholder(nombre);
  }

  Widget _colorPlaceholder(String nombre) {
    return Container(
      color: colors.primary.withOpacity(0.15),
      child: Center(
        child: Text(
          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'S',
          style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w700,
              color: colors.primary),
        ),
      ),
    );
  }

  Widget _seccion(String titulo, String contenido) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text(contenido,
            style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5)),
      ],
    );
  }

  Widget _seccionIcono(IconData icono, String titulo, String contenido) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 2),
              Text(contenido,
                  style: TextStyle(
                      fontSize: 13, color: colors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
