import 'package:flutter/material.dart';

import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import 'mapa_mini.dart';

/// Resultado de "Enviar mi ubicación": dónde y qué necesita.
class UbicacionCompartida {
  final double lat;
  final double lng;
  final String texto;
  const UbicacionCompartida(this.lat, this.lng, this.texto);
}

/// Hoja "📍 Estoy aquí": toma el GPS, muestra el mapa y deja escribir qué
/// se necesita ("Estoy aquí, necesito un gasfíter…"). [publico] avisa que
/// en Comunidad la ubicación se comparte aproximada (~100 m).
Future<UbicacionCompartida?> pedirUbicacionCompartida(BuildContext context,
    {bool publico = true}) {
  return showModalBottomSheet<UbicacionCompartida>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _HojaUbicacion(publico: publico),
  );
}

class _HojaUbicacion extends StatefulWidget {
  final bool publico;
  const _HojaUbicacion({required this.publico});

  @override
  State<_HojaUbicacion> createState() => _HojaUbicacionState();
}

class _HojaUbicacionState extends State<_HojaUbicacion> {
  Coordenadas? _yo;
  bool _buscando = true;
  final _texto = TextEditingController(text: 'Estoy aquí, necesito ');

  static const _sugerencias = [
    'Estoy aquí, necesito ',
    'Busco un técnico cerca',
    '¿Alguien vende esto cerca?',
    'Puedo retirar aquí',
  ];

  @override
  void initState() {
    super.initState();
    UbicacionService.obtener(usarCache: false).then((c) {
      if (mounted) {
        setState(() {
          _yo = c;
          _buscando = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yo = _yo;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        top: false,
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
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.location_on_rounded, color: colors.primary),
              const SizedBox(width: 6),
              Text('Enviar mi ubicación',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary)),
            ]),
            const SizedBox(height: 10),
            if (_buscando)
              SizedBox(
                height: 130,
                child: Center(
                    child: CircularProgressIndicator(color: colors.primary)),
              )
            else if (yo == null)
              Container(
                height: 90,
                alignment: Alignment.center,
                child: Text(
                    'No pudimos leer tu ubicación.\nActiva el GPS y dale permiso a OkVenta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textPrimary)),
              )
            else
              MapaMini(lat: yo.lat, lng: yo.lng, alto: 140, abrirAlTocar: false),
            if (widget.publico) ...[
              const SizedBox(height: 6),
              Text('En Comunidad se comparte aproximada (~100 m), no tu dirección exacta.',
                  style: TextStyle(fontSize: 11.5, color: colors.textPrimary)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sugerencias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_sugerencias[i].trim(),
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _texto.text = _sugerencias[i];
                    _texto.selection =
                        TextSelection.collapsed(offset: _texto.text.length);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _texto,
              maxLines: 3,
              minLines: 1,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '¿Qué necesitas?',
                filled: true,
                fillColor: colors.background,
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: yo == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        UbicacionCompartida(
                            yo.lat, yo.lng, _texto.text.trim())),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar ubicación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
