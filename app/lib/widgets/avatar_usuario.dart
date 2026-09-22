import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Arma la dirección completa de una foto de perfil.
///
/// La foto puede llegar de dos formas y había pantallas que solo
/// contemplaban una:
///   · "/uploads/perfil_12_ab.jpg"  → la que sube el usuario; es relativa
///     y hay que anteponerle el servidor.
///   · "https://lh3.googleusercontent…" → la que trae Google al iniciar
///     sesión; ya es completa.
/// Pegarle el servidor a la segunda producía una dirección imposible y la
/// foto no cargaba para nadie más que el dueño (que la ve desde su propio
/// teléfono). Devuelve null si no hay foto.
String? urlFotoPerfil(String? foto) {
  final f = (foto ?? '').trim();
  if (f.isEmpty) return null;
  if (f.startsWith('http://') || f.startsWith('https://')) return f;
  return '${ApiService.baseUrl}${f.startsWith('/') ? f : '/$f'}';
}

/// La foto de perfil de cualquier usuario, igual en toda la app.
///
/// Queda guardada en el teléfono después de verla una vez
/// (CachedNetworkImage la escribe en disco): la segunda vez aparece al
/// instante y sin gastar datos. No hace falta borrar esa copia a mano cuando
/// el usuario cambia de foto: cada subida genera un nombre de archivo nuevo,
/// así que la dirección cambia y la copia vieja simplemente deja de usarse.
///
/// Sin foto —o si la foto no carga— muestra la inicial del nombre, para que
/// nunca quede un círculo vacío.
class AvatarUsuario extends StatelessWidget {
  final String? fotoUrl;
  final String nombre;
  final double tamano;

  const AvatarUsuario({
    super.key,
    required this.fotoUrl,
    required this.nombre,
    this.tamano = 40,
  });

  String get _inicial {
    final n = nombre.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  Widget _conInicial() {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary.withValues(alpha: 0.12),
      ),
      child: Text(
        _inicial,
        style: TextStyle(
          fontSize: tamano * 0.42,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = urlFotoPerfil(fotoUrl);
    if (url == null) return _conInicial();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: tamano,
        height: tamano,
        fit: BoxFit.cover,
        // Mientras llega se ve la inicial, no un hueco: así el círculo nunca
        // "salta" de vacío a lleno.
        placeholder: (_, __) => _conInicial(),
        errorWidget: (_, __, ___) => _conInicial(),
        // La foto se guarda achicada al doble del tamaño en pantalla: nítida
        // en pantallas retina y sin llenar la memoria con fotos de 4000 px.
        memCacheWidth: (tamano * 3).round(),
      ),
    );
  }
}
