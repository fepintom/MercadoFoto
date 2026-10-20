import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/ajustes_mapa.dart';
import '../services/mapas_config.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

/// Panel para elegir el mapa de CARTO y probar su color en vivo (brillo,
/// contraste, saturación, tono e invertir), por separado para modo claro y
/// oscuro.
/// Lo que se ajusta aquí aplica solo en este teléfono; con "Copiar
/// valores" se pegan en el chat para dejarlos fijos para todos.
class AjustesMapaScreen extends StatefulWidget {
  const AjustesMapaScreen({super.key});

  @override
  State<AjustesMapaScreen> createState() => _AjustesMapaScreenState();
}

class _AjustesMapaScreenState extends State<AjustesMapaScreen> {
  late bool _oscuro = ThemeService.isDarkMode;

  AjusteMapa get _a => AjustesMapa.para(_oscuro);

  void _cambiar(AjusteMapa nuevo) {
    AjustesMapa.cambiar(modoOscuro: _oscuro, ajuste: nuevo);
    setState(() {});
  }

  Future<void> _copiar() async {
    await AjustesMapa.guardar();
    await Clipboard.setData(ClipboardData(text: AjustesMapa.valoresTexto()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Valores copiados. Pégalos en el chat para dejarlos fijos.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _restablecer() async {
    await AjustesMapa.restablecer();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: const Text('Ajustes del mapa'),
      ),
      body: Column(
        children: [
          // ── Vista previa ──────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(-33.4372, -70.6506), // Santiago centro
                zoom: 15,
                maxZoom: 19,
              ),
              children: [
                ...MapasConfig.capas(oscuro: _oscuro),
              ],
            ),
          ),
          // ── Controles ─────────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Container(
              color: colors.surface,
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _selectorModo(),
                    const SizedBox(height: 12),
                    Text('Mapa base',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in MapasCarto.disponibles.keys)
                          ChoiceChip(
                            label: Text(MapasCarto.nombre(id)),
                            selected: _a.mapa == id,
                            selectedColor: colors.primary,
                            labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _a.mapa == id
                                    ? Colors.white
                                    : colors.textPrimary),
                            onSelected: (_) {
                              _cambiar(_a.copyWith(mapa: id));
                              AjustesMapa.guardar();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _deslizador('Brillo', _a.brillo, -100, 100,
                        (v) => _cambiar(_a.copyWith(brillo: v)),
                        decimales: 0),
                    _deslizador('Contraste', _a.contraste, 0.5, 2.5,
                        (v) => _cambiar(_a.copyWith(contraste: v))),
                    _deslizador('Saturación', _a.saturacion, 0, 2,
                        (v) => _cambiar(_a.copyWith(saturacion: v))),
                    _deslizador('Tono', _a.tono, -180, 180,
                        (v) => _cambiar(_a.copyWith(tono: v)),
                        decimales: 0, sufijo: '°'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Invertir (claro ↔ oscuro)',
                          style: TextStyle(
                              fontSize: 14, color: colors.textPrimary)),
                      value: _a.invertir,
                      activeColor: colors.primary,
                      onChanged: (v) {
                        _cambiar(_a.copyWith(invertir: v));
                        AjustesMapa.guardar();
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _restablecer,
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Restablecer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copiar,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copiar valores'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      'Los cambios se ven al instante en todos los mapas de '
                      'este teléfono. "Copiar valores" copia los de claro y '
                      'oscuro para dejarlos fijos para todos.',
                      style: TextStyle(fontSize: 12, color: colors.grayMid),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorModo() {
    Widget boton(String texto, IconData icono, bool oscuro) {
      final sel = _oscuro == oscuro;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _oscuro = oscuro),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono,
                    size: 18, color: sel ? Colors.white : colors.textPrimary),
                const SizedBox(width: 6),
                Text(texto,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : colors.textPrimary)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        boton('Modo claro', Icons.light_mode_outlined, false),
        const SizedBox(width: 4),
        boton('Modo oscuro', Icons.dark_mode_outlined, true),
      ]),
    );
  }

  Widget _deslizador(String titulo, double valor, double min, double max,
      ValueChanged<double> alCambiar,
      {int decimales = 2, String sufijo = ''}) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(titulo,
              style: TextStyle(fontSize: 13.5, color: colors.textPrimary)),
        ),
        Expanded(
          child: Slider(
            value: valor.clamp(min, max).toDouble(),
            min: min,
            max: max,
            activeColor: colors.primary,
            onChanged: alCambiar,
            onChangeEnd: (_) => AjustesMapa.guardar(),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text('${valor.toStringAsFixed(decimales)}$sufijo',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary)),
        ),
      ],
    );
  }
}
