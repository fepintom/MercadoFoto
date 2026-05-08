/// Formatea un precio numérico como moneda chilena sin decimales.
/// Ejemplo: 255000 → "$255.000"
String formatPrecio(dynamic precio) {
  if (precio == null) return '';
  final n = (precio as num).toInt();
  // Separador de miles con punto (formato CLP)
  final str = n.toString();
  final buffer = StringBuffer();
  final offset = str.length % 3;
  for (int i = 0; i < str.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return '\$${buffer.toString()}';
}
