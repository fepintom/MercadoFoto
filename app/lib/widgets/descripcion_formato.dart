import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ── Formato de la descripción ───────────────────────────────────────────────
//
// El formato se guarda como texto con dos marcas mínimas, no como un
// documento enriquecido:
//
//   **así va la negrita**
//   • así empieza una viñeta
//
// Por qué así y no un editor de texto enriquecido completo:
//   · Las descripciones que ya existen siguen viéndose igual: no tienen
//     marcas y se muestran tal cual.
//   · El buscador sigue encontrando las palabras (el texto sigue siendo
//     texto; las marcas son dos asteriscos y un punto).
//   · No hay que migrar la base de datos ni tocar el servidor.
//   · Si mañana la descripción se muestra en otro lado —una web, un
//     correo— se lee bien aunque ese lugar no entienda las marcas.

const String kVineta = '• ';

/// El cuadro para escribir la descripción, con su barra de formato.
///
/// Enter hace salto de línea (antes el teclado podía mostrar "Listo" y no
/// había forma de separar párrafos). Si la línea actual es una viñeta, Enter
/// empieza la siguiente viñeta sola; Enter sobre una viñeta vacía la cierra,
/// igual que en las notas del teléfono.
class EditorDescripcion extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final String? pista;
  final int? maxLength;
  final String? Function(String?)? validator;

  const EditorDescripcion({
    super.key,
    required this.controller,
    this.etiqueta = 'Descripción',
    this.pista,
    this.maxLength,
    this.validator,
  });

  @override
  State<EditorDescripcion> createState() => _EditorDescripcionState();
}

class _EditorDescripcionState extends State<EditorDescripcion> {
  TextEditingController get _c => widget.controller;

  /// Texto anterior, para detectar que se acaba de pulsar Enter.
  late String _previo;

  /// Evita que el propio ajuste de viñetas se vuelva a procesar.
  bool _ajustando = false;

  @override
  void initState() {
    super.initState();
    _previo = _c.text;
    _c.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _c.removeListener(_alCambiar);
    super.dispose();
  }

  /// Continúa o cierra la viñeta al pulsar Enter.
  void _alCambiar() {
    if (_ajustando) return;
    final texto = _c.text;
    final sel = _c.selection;
    final anterior = _previo;
    _previo = texto;

    // Solo interesa el caso "se escribió exactamente un salto de línea".
    if (!sel.isValid || !sel.isCollapsed) return;
    if (texto.length != anterior.length + 1) return;
    final pos = sel.baseOffset;
    if (pos < 1 || texto[pos - 1] != '\n') return;

    // Línea que acaba de terminar.
    final inicio = texto.lastIndexOf('\n', pos - 2) + 1;
    final linea = texto.substring(inicio, pos - 1);
    if (!linea.startsWith(kVineta)) return;

    _ajustando = true;
    if (linea.trim() == kVineta.trim()) {
      // Viñeta vacía + Enter → se cierra la lista.
      final nuevo = texto.substring(0, inicio) + texto.substring(pos);
      _c.value = TextEditingValue(
        text: nuevo,
        selection: TextSelection.collapsed(offset: inicio),
      );
    } else {
      final nuevo = texto.substring(0, pos) + kVineta + texto.substring(pos);
      _c.value = TextEditingValue(
        text: nuevo,
        selection: TextSelection.collapsed(offset: pos + kVineta.length),
      );
    }
    _previo = _c.text;
    _ajustando = false;
  }

  /// Pone o saca `**` alrededor de lo seleccionado. Sin selección, deja las
  /// marcas puestas con el cursor en medio, listo para escribir en negrita.
  void _negrita() {
    final t = _c.text;
    var sel = _c.selection;
    if (!sel.isValid) sel = TextSelection.collapsed(offset: t.length);
    final a = sel.start, b = sel.end;
    final elegido = t.substring(a, b);

    _ajustando = true;
    if (elegido.startsWith('**') && elegido.endsWith('**') && elegido.length >= 4) {
      final limpio = elegido.substring(2, elegido.length - 2);
      _c.value = TextEditingValue(
        text: t.replaceRange(a, b, limpio),
        selection: TextSelection(baseOffset: a, extentOffset: a + limpio.length),
      );
    } else {
      final nuevo = '**$elegido**';
      _c.value = TextEditingValue(
        text: t.replaceRange(a, b, nuevo),
        selection: elegido.isEmpty
            ? TextSelection.collapsed(offset: a + 2)
            : TextSelection(baseOffset: a, extentOffset: a + nuevo.length),
      );
    }
    _previo = _c.text;
    _ajustando = false;
  }

  /// Pone o saca la viñeta en todas las líneas tocadas por la selección.
  void _vineta() {
    final t = _c.text;
    var sel = _c.selection;
    if (!sel.isValid) sel = TextSelection.collapsed(offset: t.length);

    final inicio = sel.start == 0 ? 0 : t.lastIndexOf('\n', sel.start - 1) + 1;
    var fin = t.indexOf('\n', sel.end);
    if (fin == -1) fin = t.length;

    final lineas = t.substring(inicio, fin).split('\n');
    final todasConVineta =
        lineas.every((l) => l.startsWith(kVineta) || l.isEmpty) &&
            lineas.any((l) => l.startsWith(kVineta));
    final nuevas = lineas.map((l) {
      if (todasConVineta) {
        return l.startsWith(kVineta) ? l.substring(kVineta.length) : l;
      }
      return l.startsWith(kVineta) ? l : '$kVineta$l';
    }).join('\n');

    _ajustando = true;
    _c.value = TextEditingValue(
      text: t.replaceRange(inicio, fin, nuevas),
      selection: TextSelection.collapsed(offset: inicio + nuevas.length),
    );
    _previo = _c.text;
    _ajustando = false;
  }

  Widget _boton(IconData icono, String ayuda, VoidCallback onTap) {
    return Tooltip(
      message: ayuda,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Icon(icono, size: 20, color: colors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.etiqueta,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            children: [
              // Barra de formato: pegada al cuadro, arriba, para que se vea
              // que pertenece a este campo y no a toda la pantalla.
              Row(
                children: [
                  _boton(Icons.format_bold_rounded, 'Negrita', _negrita),
                  _boton(Icons.format_list_bulleted_rounded, 'Viñetas', _vineta),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text('Enter = nueva línea',
                        style: TextStyle(fontSize: 11, color: colors.grayMid)),
                  ),
                ],
              ),
              Divider(height: 1, color: colors.divider),
              TextFormField(
                controller: _c,
                validator: widget.validator,
                // Estas dos líneas son las que hacen que Enter salte de
                // línea en vez de cerrar el teclado.
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 5,
                maxLines: 12,
                maxLength: widget.maxLength,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontSize: 15, color: colors.textPrimary, height: 1.45),
                decoration: InputDecoration(
                  hintText: widget.pista ??
                      'Cuenta el estado, medidas, qué incluye…',
                  hintStyle: TextStyle(color: colors.grayMid, fontSize: 14),
                  // El recuadro lo pinta el Container: sin esto el tema
                  // pondría su propio borde y relleno encima.
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Muestra una descripción respetando negritas, viñetas y saltos de línea.
class TextoDescripcion extends StatelessWidget {
  final String texto;
  final TextStyle? estilo;

  const TextoDescripcion(this.texto, {super.key, this.estilo});

  /// Parte una línea en tramos normales y en negrita según los `**`.
  List<TextSpan> _tramos(String linea, TextStyle base) {
    final spans = <TextSpan>[];
    final partes = linea.split('**');
    for (var i = 0; i < partes.length; i++) {
      if (partes[i].isEmpty) continue;
      // Los tramos impares quedaron entre dos `**`. Un `**` suelto sin
      // pareja deja el último tramo impar sin cerrar: ese se muestra normal
      // y con sus asteriscos, para no poner en negrita media descripción
      // por un error de tipeo.
      final abierto = i.isOdd && i == partes.length - 1;
      final enNegrita = i.isOdd && !abierto;
      spans.add(TextSpan(
        text: abierto ? '**${partes[i]}' : partes[i],
        style: enNegrita
            ? base.copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary)
            : null,
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = estilo ??
        TextStyle(fontSize: 15, color: colors.textSecondary, height: 1.6);
    final lineas = texto.replaceAll('\r\n', '\n').split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lineas)
          if (l.startsWith(kVineta) || l.startsWith('- ') || l.startsWith('* '))
            // Viñeta con sangría colgante: si la línea es larga, el texto
            // que baja queda alineado con el de arriba y no debajo del punto.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: base.copyWith(color: colors.primary)),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: base, children: _tramos(l.substring(2), base)),
                    ),
                  ),
                ],
              ),
            )
          else if (l.trim().isEmpty)
            SizedBox(height: (base.fontSize ?? 15) * 0.6)
          else
            Text.rich(TextSpan(style: base, children: _tramos(l, base))),
      ],
    );
  }
}
