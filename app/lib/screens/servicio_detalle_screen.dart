import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

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

  Future<void> _abrirWhatsApp() async {
    final num = (_srv['whatsapp'] ?? _srv['telefono'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\D'), '');
    if (num.isEmpty) return;
    final uri = Uri.parse('https://wa.me/56$num');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')));
      }
    }
  }

  Future<void> _llamar() async {
    final num = (_srv['telefono'] ?? _srv['whatsapp'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\D'), '');
    if (num.isEmpty) return;
    final uri = Uri.parse('tel:+56$num');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada')));
      }
    }
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
        const SnackBar(
            content: Text('Este servicio no tiene un precio definido'),
            backgroundColor: AppColors.carbon),
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
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
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
        ((_srv['telefono'] ?? _srv['whatsapp'] ?? '') as String).isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar con imagen/foto ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  size: 18, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: fotos.isNotEmpty
                  ? Image.network(
                      '${ApiService.baseUrl}${fotos.first}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _fotoPlaceholder(fotoUrl, nombre),
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
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        backgroundImage: fotoUrl.isNotEmpty
                            ? NetworkImage(
                                '${ApiService.baseUrl}$fotoUrl')
                            : null,
                        child: fotoUrl.isEmpty
                            ? Text(
                                nombre.isNotEmpty
                                    ? nombre[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tipo == 'ofrezco'
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tipo == 'ofrezco' ? 'Ofrece' : 'Busca',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: tipo == 'ofrezco'
                                            ? AppColors.primary
                                            : Colors.orange),
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
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),

                  const SizedBox(height: 16),

                  // ── Precio ──────────────────────────────────────────────
                  if (valor > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary),
                              ),
                              Text(
                                'por $modalidad',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grayMid),
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
                    const Text('Fotos',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fotos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            '${ApiService.baseUrl}${fotos[i]}',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: AppColors.background,
                              child: const Icon(Icons.image,
                                  color: AppColors.grayMid),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Calificación ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Calificación',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const Spacer(),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star,
                                color: Colors.amber, size: 22),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('$numVal valoración${numVal == 1 ? '' : 'es'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grayMid)),
                        const SizedBox(height: 12),
                        // Estrellas interactivas
                        Row(
                          children: List.generate(5, (i) {
                            final sel = i < (_miRating > 0
                                ? _miRating
                                : rating.round());
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
                        ),
                        if (_enviandoRating)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(
                                color: AppColors.primary),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Botones de contacto ─────────────────────────────────
                  const Text('Contactar',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),

                  if (tieneTelefono)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _abrirWhatsApp,
                            icon: const Icon(Icons.chat, size: 18),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _llamar,
                            icon: const Icon(Icons.call, size: 18),
                            label: const Text('Llamar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.carbon,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: AppColors.grayMid),
                          SizedBox(width: 8),
                          Text('El usuario no tiene teléfono registrado',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.grayMid)),
                        ],
                      ),
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

  Widget _fotoPlaceholder(String fotoUrl, String nombre) {
    if (fotoUrl.isNotEmpty) {
      return Image.network('${ApiService.baseUrl}$fotoUrl',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _colorPlaceholder(nombre));
    }
    return _colorPlaceholder(nombre);
  }

  Widget _colorPlaceholder(String nombre) {
    return Container(
      color: AppColors.primary.withOpacity(0.15),
      child: Center(
        child: Text(
          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'S',
          style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w700,
              color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _seccion(String titulo, String contenido) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(contenido,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5)),
      ],
    );
  }

  Widget _seccionIcono(IconData icono, String titulo, String contenido) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(contenido,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
