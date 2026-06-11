import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'servicio_detalle_screen.dart';
import 'agregar_servicio_screen.dart';
import 'home_screen.dart';

class MisServiciosScreen extends StatefulWidget {
  const MisServiciosScreen({super.key});

  @override
  State<MisServiciosScreen> createState() => _MisServiciosScreenState();
}

class _MisServiciosScreenState extends State<MisServiciosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _servicios = [];
  bool _cargando = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _cargar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    _userId = await SessionService.obtenerUser();
    if (_userId == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final data = await ApiService.obtenerMisServicios(_userId!);
      if (mounted) setState(() => _servicios = data);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  List<Map<String, dynamic>> get _ofrezco =>
      _servicios.where((s) => s['tipo'] == 'ofrezco').toList();

  List<Map<String, dynamic>> get _busco =>
      _servicios.where((s) => s['tipo'] == 'busco').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HomeScreen()),
                                (r) => false,
                              );
                            }
                          },
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 20, color: AppColors.carbon),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Mis servicios',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Botón nuevo servicio
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AgregarServicioScreen()),
                            );
                            _cargar();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Nuevo',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabs
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.grayMid,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(
                        text: 'Ofrezco'
                            '${_ofrezco.isNotEmpty ? ' (${_ofrezco.length})' : ''}',
                      ),
                      Tab(
                        text: 'Busco'
                            '${_busco.isNotEmpty ? ' (${_busco.length})' : ''}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Contenido ───────────────────────────────────────────────
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _ListaServicios(
                          servicios: _ofrezco,
                          tipo: 'ofrezco',
                          userId: _userId,
                          onRefresh: _cargar,
                        ),
                        _ListaServicios(
                          servicios: _busco,
                          tipo: 'busco',
                          userId: _userId,
                          onRefresh: _cargar,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lista de servicios por tab ────────────────────────────────────────────────

class _ListaServicios extends StatelessWidget {
  final List<Map<String, dynamic>> servicios;
  final String tipo;
  final int? userId;
  final VoidCallback onRefresh;

  const _ListaServicios({
    required this.servicios,
    required this.tipo,
    required this.userId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (servicios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tipo == 'ofrezco'
                  ? Icons.handyman_outlined
                  : Icons.search_outlined,
              size: 56,
              color: AppColors.grayMid,
            ),
            const SizedBox(height: 12),
            Text(
              tipo == 'ofrezco'
                  ? 'No tienes servicios publicados'
                  : 'No tienes búsquedas publicadas',
              style: const TextStyle(color: AppColors.grayMid, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: servicios.length,
        itemBuilder: (_, i) => _TarjetaServicio(
          servicio: servicios[i],
          userId: userId,
          onRefresh: onRefresh,
        ),
      ),
    );
  }
}

// ── Tarjeta de servicio ───────────────────────────────────────────────────────

class _TarjetaServicio extends StatefulWidget {
  final Map<String, dynamic> servicio;
  final int? userId;
  final VoidCallback onRefresh;

  const _TarjetaServicio({
    required this.servicio,
    required this.userId,
    required this.onRefresh,
  });

  @override
  State<_TarjetaServicio> createState() => _TarjetaServicioState();
}

class _TarjetaServicioState extends State<_TarjetaServicio> {
  bool _expandido = false;
  List<Map<String, dynamic>>? _contactos;
  bool _cargandoContactos = false;

  Future<void> _cargarContactos() async {
    if (widget.userId == null) return;
    setState(() => _cargandoContactos = true);
    try {
      final data = await ApiService.obtenerContactosServicio(
        widget.servicio['id'] as int,
        widget.userId!,
      );
      if (mounted) setState(() => _contactos = data);
    } catch (_) {}
    if (mounted) setState(() => _cargandoContactos = false);
  }

  void _toggleContactos() {
    setState(() => _expandido = !_expandido);
    if (_expandido && _contactos == null) _cargarContactos();
  }

  String _formatFecha(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatHora(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.servicio;
    final colorHex = (s['color_hex'] as String? ?? '#007AFF')
        .replaceFirst('#', '');
    final color = Color(int.parse('FF$colorHex', radix: 16));
    final numContactos = (s['num_contactos'] as num?)?.toInt() ?? 0;
    final categoria = s['categoria'] as String? ?? 'Otros';
    final valor = s['valor'];
    final modalidad = s['modalidad'] as String? ?? 'servicio';

    return GestureDetector(
      onTap: () async {
        // Navegar al detalle del servicio
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServicioDetalleScreen(servicio: s),
          ),
        );
        widget.onRefresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Cuerpo principal ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color badge del tipo
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.handyman_outlined,
                        size: 22, color: color),
                  ),
                  const SizedBox(width: 12),

                  // Título + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['titulo'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _chip(categoria, AppColors.grayMid),
                            const SizedBox(width: 6),
                            if (valor != null && (valor as num) > 0)
                              _chip(
                                '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}${modalidad == 'hora' ? '/hr' : ''}',
                                color,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Fecha
                  Text(
                    _formatFecha(s['created_at'] as String?),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.grayMid),
                  ),
                ],
              ),
            ),

            // ── Footer: contactos ────────────────────────────────────────
            GestureDetector(
              onTap: _toggleContactos,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: numContactos > 0
                      ? const Color(0xFF00897B).withOpacity(0.06)
                      : AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14)),
                  border: Border(
                    top: BorderSide(
                        color: AppColors.divider, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 15,
                      color: numContactos > 0
                          ? const Color(0xFF00897B)
                          : AppColors.grayMid,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      numContactos == 0
                          ? 'Sin contactos aún'
                          : '$numContactos contacto${numContactos > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: numContactos > 0
                            ? const Color(0xFF00897B)
                            : AppColors.grayMid,
                      ),
                    ),
                    const Spacer(),
                    if (numContactos > 0)
                      Icon(
                        _expandido
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.grayMid,
                      ),
                  ],
                ),
              ),
            ),

            // ── Lista de contactos expandida ─────────────────────────────
            if (_expandido) ...[
              if (_cargandoContactos)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                )
              else if (_contactos != null && _contactos!.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  itemCount: _contactos!.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final c = _contactos![i];
                    final esWpp = c['tipo_contacto'] == 'whatsapp';
                    return GestureDetector(
                      onTap: () async {
                        // Navegar al detalle del servicio
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ServicioDetalleScreen(servicio: s),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: esWpp
                                    ? const Color(0xFF25D366).withOpacity(0.1)
                                    : AppColors.carbon.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                esWpp ? Icons.chat_rounded : Icons.call_rounded,
                                size: 15,
                                color: esWpp
                                    ? const Color(0xFF25D366)
                                    : AppColors.carbon,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['nombre_contactante'] as String? ??
                                        'Anónimo',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    esWpp ? 'WhatsApp' : 'Llamada',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grayMid),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatFecha(c['created_at'] as String?),
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.grayMid),
                                ),
                                Text(
                                  _formatHora(c['created_at'] as String?),
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.grayMid),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 11, color: AppColors.grayMid),
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: const Text('No hay contactos registrados aún',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.grayMid)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
