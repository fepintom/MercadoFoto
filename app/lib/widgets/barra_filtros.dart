import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/regiones_chile.dart';
import 'barra_radio_km.dart';

/// Qué panel está desplegado bajo la fila de filtros.
enum PanelFiltro { ninguno, distancia, categorias }

/// Una categoría para la barra: nombre + ícono.
class OpcionCategoria {
  final String nombre;
  final IconData icono;
  const OpcionCategoria(this.nombre, this.icono);
}

/// La fila de filtros de OkMarket y OkServicios, en un solo lugar.
///
///   [◎ Filtro de búsqueda] [Categorías ▼] [Biobío] [Hogar] ...  [+ Publicar]
///
/// - "Filtro de búsqueda" y "Categorías" despliegan su panel debajo.
///   El filtro tiene dos modos: "Cerca de mí" (radio en km desde el GPS) y
///   "Por zona" (una o varias regiones, para buscar lejos de donde uno
///   está; p. ej. comprarle algo a un pariente que vive en otra región).
///   El botón dice su estado ("50 km", "Biobío", "2 regiones") en rojo
///   cuando filtra, para que el usuario sepa por qué ve menos avisos.
/// - Las categorías elegidas quedan arriba, en rojo, como filtros puestos.
///   Para quitar una se mantiene presionada y se arrastra fuera: se esfuma.
/// - "Publicar" va fijo a la derecha, donde cae el pulgar al sostener el
///   teléfono con la mano derecha.
///
/// No guarda estado: la pantalla que la usa manda los valores y recibe los
/// cambios. Así el alto del encabezado anclado se puede calcular afuera con
/// [BarraFiltros.alto].
class BarraFiltros extends StatelessWidget {
  // Distancia
  final double radioKm;
  final bool distanciaActiva;
  final bool sinGps;
  final bool cargandoUbicacion;
  final ValueChanged<double> onRadioChanged;
  final ValueChanged<double>? onRadioSoltado;
  final VoidCallback? onToggleDistancia;

  // Zona (regiones). Sin [onModoZona] la barra solo ofrece distancia.
  final bool modoZona;
  final List<String> regiones;
  final ValueChanged<bool>? onModoZona;
  final ValueChanged<String>? onAgregarRegion;
  final ValueChanged<String>? onQuitarRegion;

  // Categorías
  final List<OpcionCategoria> categorias;
  final List<String> seleccionadas;
  final ValueChanged<String> onAgregarCategoria;
  final ValueChanged<String> onQuitarCategoria;

  /// Fila extra dentro del panel de categorías, debajo de las categorías
  /// (el marketplace la usa para las subcategorías).
  final Widget? extraCategorias;

  // Panel
  final PanelFiltro panel;
  final ValueChanged<PanelFiltro> onPanel;

  // Publicar
  final VoidCallback? onPublicar;
  final String etiquetaPublicar;

  /// Color de fondo de la franja.
  final Color? fondo;

  const BarraFiltros({
    super.key,
    required this.radioKm,
    required this.distanciaActiva,
    required this.onRadioChanged,
    required this.categorias,
    required this.seleccionadas,
    required this.onAgregarCategoria,
    required this.onQuitarCategoria,
    required this.panel,
    required this.onPanel,
    this.sinGps = false,
    this.cargandoUbicacion = false,
    this.onRadioSoltado,
    this.onToggleDistancia,
    this.modoZona = false,
    this.regiones = const [],
    this.onModoZona,
    this.onAgregarRegion,
    this.onQuitarRegion,
    this.extraCategorias,
    this.onPublicar,
    this.etiquetaPublicar = 'Publicar',
    this.fondo,
  });

  static const double altoFila = 46;
  static const double altoModos = 40;
  static const double altoPanelDistancia = 50;
  static const double altoPanelRegiones = 44;
  static const double altoPanelCategorias = 44;
  static const double altoExtra = 36;

  /// Alto total según lo desplegado. Lo necesita el SliverPersistentHeader.
  static double alto(PanelFiltro panel,
      {bool conExtra = false, bool modoZona = false, bool conZona = true}) {
    switch (panel) {
      case PanelFiltro.distancia:
        return altoFila +
            (conZona ? altoModos : 0) +
            (modoZona ? altoPanelRegiones : altoPanelDistancia);
      case PanelFiltro.categorias:
        return altoFila + altoPanelCategorias + (conExtra ? altoExtra : 0);
      case PanelFiltro.ninguno:
        return altoFila;
    }
  }

  void _alternar(PanelFiltro p) {
    HapticFeedback.selectionClick();
    onPanel(panel == p ? PanelFiltro.ninguno : p);
  }

  @override
  Widget build(BuildContext context) {
    final bg = fondo ?? colors.surface;
    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: altoFila,
            child: Row(
              children: [
                Expanded(
                  child: ShaderMask(
                    // Degradado a la derecha: avisa que la fila sigue y
                    // que las pastillas no se cortan contra Publicar.
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, 0.9, 1],
                    ).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                      children: [
                        _botonDistancia(),
                        const SizedBox(width: 6),
                        _botonCategorias(),
                        if (modoZona)
                          for (final r in regiones) ...[
                            const SizedBox(width: 6),
                            PastillaQuitable(
                              key: ValueKey('reg-$r'),
                              etiqueta: r,
                              icono: Icons.place_outlined,
                              onQuitar: () => onQuitarRegion?.call(r),
                            ),
                          ],
                        for (final c in seleccionadas) ...[
                          const SizedBox(width: 6),
                          PastillaQuitable(
                            key: ValueKey('cat-$c'),
                            etiqueta: c,
                            icono: _icono(c),
                            onQuitar: () => onQuitarCategoria(c),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (onPublicar != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    child: _BotonPublicar(
                        etiqueta: etiquetaPublicar, onTap: onPublicar!),
                  ),
              ],
            ),
          ),
          // Sin AnimatedSize a propósito: el encabezado anclado que la
          // contiene cambia de alto de golpe (SliverPersistentHeader no
          // anima), y un contenido que se encoge de a poco se saldría de él
          // durante la animación.
          _panelDesplegado(),
        ],
      ),
    );
  }

  Widget _panelDesplegado() {
    switch (panel) {
      case PanelFiltro.distancia:
        return _panelFiltro();
      case PanelFiltro.categorias:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _carruselCategorias(),
            if (extraCategorias != null)
              SizedBox(height: altoExtra, child: extraCategorias),
          ],
        );
      case PanelFiltro.ninguno:
        return const SizedBox(width: double.infinity);
    }
  }

  IconData _icono(String nombre) => categorias
      .firstWhere((c) => c.nombre == nombre,
          orElse: () => OpcionCategoria(nombre, Icons.label_outline_rounded))
      .icono;

  // ── Botones de la fila ──────────────────────────────────────────────────

  Widget _botonDistancia() {
    final abierto = panel == PanelFiltro.distancia;
    if (modoZona) {
      final activo = regiones.isNotEmpty;
      return _PastillaBoton(
        icono: Icons.map_outlined,
        texto: !activo
            ? 'Filtro de búsqueda'
            : regiones.length == 1
                ? 'Zona'
                : '${regiones.length} regiones',
        activo: activo,
        abierto: abierto,
        flecha: true,
        onTap: () => _alternar(PanelFiltro.distancia),
      );
    }
    final encendido = distanciaActiva && !sinGps;
    final texto = encendido
        ? BarraRadioKm.formatRadio(radioKm)
        : 'Filtro de búsqueda';
    return _PastillaBoton(
      icono: Icons.near_me_rounded,
      texto: texto,
      activo: encendido,
      flecha: true,
      abierto: abierto,
      onTap: () => _alternar(PanelFiltro.distancia),
    );
  }

  Widget _botonCategorias() {
    final abierto = panel == PanelFiltro.categorias;
    return _PastillaBoton(
      icono: Icons.grid_view_rounded,
      texto: 'Categorías',
      activo: false,
      abierto: abierto,
      flecha: true,
      onTap: () => _alternar(PanelFiltro.categorias),
    );
  }

  Widget _panelFiltro() {
    final radio = BarraRadioKm(
      radioKm: radioKm,
      activo: distanciaActiva,
      sinGps: sinGps,
      cargando: cargandoUbicacion,
      onChanged: onRadioChanged,
      onChangeEnd: onRadioSoltado,
      onToggle: onToggleDistancia,
    );
    if (onModoZona == null) return radio;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _filaModos(),
        modoZona ? _carruselRegiones() : radio,
      ],
    );
  }

  // ── Panel del filtro de búsqueda ───────────────────────────────────────

  /// "Cerca de mí" / "Por zona". Solo uno filtra a la vez: buscar en otra
  /// región y a la vez a 10 km de mí no tiene sentido.
  Widget _filaModos() {
    Widget opcion(String texto, IconData icono, bool sel, bool zona) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (sel) return;
            HapticFeedback.selectionClick();
            onModoZona?.call(zona);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: sel ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: sel
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1))
                    ]
                  : const [],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono,
                    size: 14, color: sel ? colors.primary : colors.grayMid),
                const SizedBox(width: 5),
                Text(texto,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? colors.textPrimary : colors.grayMid)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: altoModos,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          opcion('Cerca de mí', Icons.near_me_rounded, !modoZona, false),
          opcion('Por zona', Icons.map_outlined, modoZona, true),
        ]),
      ),
    );
  }

  /// Regiones de norte a sur. Las elegidas suben a la fila de arriba.
  Widget _carruselRegiones() {
    final disponibles =
        RegionesChile.nombres.where((r) => !regiones.contains(r)).toList();
    return SizedBox(
      height: altoPanelRegiones,
      child: disponibles.isEmpty
          ? Center(
              child: Text('Todas las regiones están en el filtro',
                  style: TextStyle(fontSize: 12, color: colors.grayMid)))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              itemCount: disponibles.length,
              itemBuilder: (_, i) {
                final r = disponibles[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onAgregarRegion?.call(r);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_outlined,
                              size: 13, color: colors.grayMid),
                          const SizedBox(width: 4),
                          Text(r,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary)),
                          const SizedBox(width: 3),
                          Icon(Icons.add_rounded,
                              size: 13, color: colors.grayMid),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ── Panel de categorías: una sola línea que se desliza ─────────────────

  Widget _carruselCategorias() {
    final disponibles =
        categorias.where((c) => !seleccionadas.contains(c.nombre)).toList();
    return Container(
      height: altoPanelCategorias,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: disponibles.isEmpty
          ? Center(
              child: Text('Todas las categorías están en el filtro',
                  style: TextStyle(fontSize: 12, color: colors.grayMid)))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              itemCount: disponibles.length,
              itemBuilder: (_, i) {
                final c = disponibles[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onAgregarCategoria(c.nombre);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icono, size: 13, color: colors.grayMid),
                          const SizedBox(width: 5),
                          Text(c.nombre,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary)),
                          const SizedBox(width: 3),
                          Icon(Icons.add_rounded,
                              size: 13, color: colors.grayMid),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Distancia / Categorías: borde fino, rojo cuando el filtro está puesto.
class _PastillaBoton extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final bool abierto;
  final bool flecha;
  final VoidCallback onTap;

  const _PastillaBoton({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.abierto,
    required this.onTap,
    this.flecha = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? colors.primary : colors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: abierto ? colors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activo ? colors.primary : colors.divider,
            width: activo ? 1 : 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 13, color: activo ? colors.primary : colors.grayMid),
            const SizedBox(width: 5),
            Text(texto,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: color)),
            if (flecha || abierto) ...[
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: abierto ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: colors.grayMid),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "+ Publicar": único botón relleno de la fila, para que no compita.
class _BotonPublicar extends StatelessWidget {
  final String etiqueta;
  final VoidCallback onTap;
  const _BotonPublicar({required this.etiqueta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: colors.primarySuave,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.primarySuave.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 15, color: Colors.white),
            const SizedBox(width: 3),
            Text(etiqueta,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pastilla que se quita arrastrándola fuera
// ═══════════════════════════════════════════════════════════════════════════

/// Categoría puesta en el filtro. Se quita manteniéndola presionada y
/// arrastrándola fuera de la barra: al soltarla lejos se esfuma (se agranda,
/// se desenfoca y se desvanece soltando unas chispas). Si se suelta cerca,
/// vuelve a su lugar.
///
/// El arrastre se dibuja en el Overlay y no dentro de la fila: la fila es
/// una lista con scroll que recorta lo que sale de sus bordes, y la gracia
/// es justamente sacarla de ahí.
///
/// Se activa con una pulsación corta (180 ms) y no con un arrastre directo
/// porque la fila se desliza horizontalmente y la pantalla verticalmente:
/// sin la pulsación previa, esos scrolls se quedarían con el gesto.
class PastillaQuitable extends StatefulWidget {
  final String etiqueta;
  final IconData icono;
  final VoidCallback onQuitar;

  /// Distancia desde el punto de partida a la que soltar ya la quita.
  final double distanciaQuitar;

  const PastillaQuitable({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.onQuitar,
    this.distanciaQuitar = 44,
  });

  @override
  State<PastillaQuitable> createState() => _PastillaQuitableState();
}

class _PastillaQuitableState extends State<PastillaQuitable> {
  OverlayEntry? _entry;
  final _drag = ValueNotifier<_EstadoArrastre?>(null);
  Offset _origen = Offset.zero;
  Size _tam = Size.zero;
  bool _oculta = false;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _drag.dispose();
    super.dispose();
  }

  void _inicio(LongPressStartDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _origen = box.localToGlobal(Offset.zero);
    _tam = box.size;
    HapticFeedback.mediumImpact();
    _drag.value = _EstadoArrastre(Offset.zero, false);
    _entry = OverlayEntry(
      builder: (_) => _PastillaFlotante(
        origen: _origen,
        tam: _tam,
        estado: _drag,
        distanciaQuitar: widget.distanciaQuitar,
        pastilla: _Pastilla(etiqueta: widget.etiqueta, icono: widget.icono),
        onFin: _finAnimacion,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() => _oculta = true);
  }

  void _mover(LongPressMoveUpdateDetails d) {
    final e = _drag.value;
    if (e == null || e.soltado) return;
    final lejos = d.offsetFromOrigin.distance >= widget.distanciaQuitar;
    if (lejos != e.lejos) HapticFeedback.selectionClick();
    _drag.value = _EstadoArrastre(d.offsetFromOrigin, false);
  }

  void _soltar(LongPressEndDetails d) {
    final e = _drag.value;
    if (e == null) return;
    _drag.value = _EstadoArrastre(e.offset, true);
    if (e.lejos) HapticFeedback.lightImpact();
  }

  void _finAnimacion(bool quitada) {
    _entry?.remove();
    _entry = null;
    _drag.value = null;
    if (!mounted) return;
    if (quitada) {
      widget.onQuitar();
    } else {
      setState(() => _oculta = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Un toque normal explica cómo se quita: si no, nadie lo adivina.
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: const Text(
                'Mantén presionada la categoría y arrástrala fuera para quitarla'),
            backgroundColor: colors.carbon,
            duration: const Duration(seconds: 2),
          ));
      },
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 180)),
            (r) => r
              ..onLongPressStart = _inicio
              ..onLongPressMoveUpdate = _mover
              ..onLongPressEnd = _soltar,
          ),
        },
        child: Opacity(
          opacity: _oculta ? 0 : 1,
          child: _Pastilla(etiqueta: widget.etiqueta, icono: widget.icono),
        ),
      ),
    );
  }
}

class _EstadoArrastre {
  final Offset offset;
  final bool soltado;
  const _EstadoArrastre(this.offset, this.soltado);
  bool get lejos => offset.distance >= 44;
}

/// El aspecto de la categoría puesta: fondo rojo suave, texto rojo.
class _Pastilla extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  const _Pastilla({required this.etiqueta, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary, width: 1),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: colors.primary),
          const SizedBox(width: 5),
          Text(etiqueta,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                  decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

/// La copia que sigue al dedo y, al soltar, vuelve o se esfuma.
class _PastillaFlotante extends StatefulWidget {
  final Offset origen;
  final Size tam;
  final ValueNotifier<_EstadoArrastre?> estado;
  final double distanciaQuitar;
  final Widget pastilla;
  final void Function(bool quitada) onFin;

  const _PastillaFlotante({
    required this.origen,
    required this.tam,
    required this.estado,
    required this.distanciaQuitar,
    required this.pastilla,
    required this.onFin,
  });

  @override
  State<_PastillaFlotante> createState() => _PastillaFlotanteState();
}

class _PastillaFlotanteState extends State<_PastillaFlotante>
    with TickerProviderStateMixin {
  late final AnimationController _esfumar = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _volver = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  Offset _desdeVolver = Offset.zero;
  bool _terminando = false;

  @override
  void initState() {
    super.initState();
    widget.estado.addListener(_cambio);
  }

  @override
  void dispose() {
    widget.estado.removeListener(_cambio);
    _esfumar.dispose();
    _volver.dispose();
    super.dispose();
  }

  void _cambio() {
    final e = widget.estado.value;
    if (e == null || !e.soltado || _terminando) {
      if (mounted) setState(() {});
      return;
    }
    _terminando = true;
    if (e.offset.distance >= widget.distanciaQuitar) {
      _esfumar.forward().whenComplete(() => widget.onFin(true));
    } else {
      _desdeVolver = e.offset;
      _volver.forward().whenComplete(() => widget.onFin(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_esfumar, _volver, widget.estado]),
        builder: (_, __) {
          final e = widget.estado.value;
          var offset = e?.offset ?? Offset.zero;
          if (_volver.isAnimating || _volver.isCompleted) {
            offset = Offset.lerp(_desdeVolver, Offset.zero,
                Curves.easeOutBack.transform(_volver.value))!;
          }
          final lejos = offset.distance >= widget.distanciaQuitar;
          final t = Curves.easeOut.transform(_esfumar.value);

          // Mientras se arrastra: levantada (más grande, con sombra). Lejos
          // de la barra: medio transparente, anticipando que se va.
          final escalaArrastre = lejos ? 1.12 : 1.06;
          final escala = escalaArrastre + t * 0.45;
          final opacidad =
              ((lejos && _esfumar.value == 0 ? 0.65 : 1.0) * (1 - t))
                  .clamp(0.0, 1.0);
          final blur = t * 8;
          final centro = widget.origen +
              offset +
              Offset(widget.tam.width / 2, widget.tam.height / 2);

          return Stack(
            children: [
              // Chispas del "puf".
              if (_esfumar.value > 0)
                Positioned(
                  left: centro.dx - 60,
                  top: centro.dy - 60,
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _Chispas(
                        progreso: _esfumar.value, color: colors.primary),
                  ),
                ),
              Positioned(
                left: widget.origen.dx + offset.dx,
                top: widget.origen.dy + offset.dy,
                width: widget.tam.width,
                height: widget.tam.height,
                child: Opacity(
                  opacity: opacidad,
                  child: Transform.scale(
                    scale: escala,
                    child: ImageFiltered(
                      imageFilter:
                          ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.18 * (1 - t)),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: widget.pastilla,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Puntitos que salen del centro y se apagan.
class _Chispas extends CustomPainter {
  final double progreso;
  final Color color;
  _Chispas({required this.progreso, required this.color});

  static const _n = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = Curves.easeOut.transform(progreso);
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progreso) * 0.8);
    for (var i = 0; i < _n; i++) {
      final ang = (i / _n) * 2 * math.pi + (i.isEven ? 0.2 : -0.1);
      final dist = 14 + t * (38 + (i % 3) * 8);
      final r = (3.2 - (i % 3) * 0.7) * (1 - t * 0.6);
      canvas.drawCircle(
          c + Offset(math.cos(ang), math.sin(ang)) * dist, r, paint);
    }
  }

  @override
  bool shouldRepaint(_Chispas old) => old.progreso != progreso;
}
