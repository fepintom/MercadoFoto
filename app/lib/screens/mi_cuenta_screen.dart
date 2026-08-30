import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'ayuda_chat_screen.dart';
import 'ayuda_screen.dart';
import 'favoritos_screen.dart';
import 'mis_compras_screen.dart';
import 'mis_publicaciones_screen.dart';
import 'mis_servicios_screen.dart';
import 'mis_ventas_screen.dart';
import 'perfil_info_screen.dart';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({super.key});

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final nombreCtrl = TextEditingController();
  final apellidoCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final rutCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final comunaCtrl = TextEditingController();
  final ciudadCtrl = TextEditingController();
  final razonSocialCtrl = TextEditingController();
  final bancoCtrl = TextEditingController();
  final tipoCuentaCtrl = TextEditingController();
  final numeroCuentaCtrl = TextEditingController();
  final correoBancoCtrl = TextEditingController();

  String tipoUsuario = "persona";
  String nombreMostrado = "";
  String _fotoUrl = "";
  int? _userId;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    cargarDatos();
    _cargarBiometria();
  }

  Future<void> _cargarBiometria() async {
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleFaceId(bool value) async {
    if (value) {
      final disponible = await BiometricService.isAvailable();
      if (!disponible) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Face ID no está disponible. Verifica que esté configurado en Ajustes del dispositivo."),
          backgroundColor: colors.carbon,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ));
        return;
      }
      final ok = await BiometricService.authenticate(
        reason: 'Confirma tu Face ID para activarlo en OkVenta',
      );
      if (!ok) return;
    }
    await BiometricService.setEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  Future<void> cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nombreCtrl.text = prefs.getString("nombre") ?? "";
      apellidoCtrl.text = prefs.getString("apellido") ?? "";
      emailCtrl.text = prefs.getString("email") ?? "";
      rutCtrl.text = prefs.getString("rut") ?? "";
      direccionCtrl.text = prefs.getString("direccion") ?? "";
      comunaCtrl.text = prefs.getString("comuna") ?? "";
      ciudadCtrl.text = prefs.getString("ciudad") ?? "";
      tipoUsuario = prefs.getString("tipo_usuario") ?? "persona";
      razonSocialCtrl.text = prefs.getString("razon_social") ?? "";
      bancoCtrl.text = prefs.getString("banco") ?? "";
      tipoCuentaCtrl.text = prefs.getString("tipo_cuenta") ?? "";
      numeroCuentaCtrl.text = prefs.getString("numero_cuenta") ?? "";
      correoBancoCtrl.text = prefs.getString("correo_banco") ?? "";
      nombreMostrado = prefs.getString("nombre") ?? "";
      _fotoUrl = prefs.getString("foto_url") ?? "";
      _userId = prefs.getInt("user_id");
    });
  }

  Future<void> guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("nombre", nombreCtrl.text);
    await prefs.setString("apellido", apellidoCtrl.text);
    await prefs.setString("email", emailCtrl.text);
    await prefs.setString("rut", rutCtrl.text);
    await prefs.setString("direccion", direccionCtrl.text);
    await prefs.setString("comuna", comunaCtrl.text);
    await prefs.setString("ciudad", ciudadCtrl.text);
    await prefs.setString("tipo_usuario", tipoUsuario);
    await prefs.setString("razon_social", razonSocialCtrl.text);
    await prefs.setString("banco", bancoCtrl.text);
    await prefs.setString("tipo_cuenta", tipoCuentaCtrl.text);
    await prefs.setString("numero_cuenta", numeroCuentaCtrl.text);
    await prefs.setString("correo_banco", correoBancoCtrl.text);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Datos guardados correctamente"),
        backgroundColor: colors.carbon,
      ),
    );
    await cargarDatos();
  }

  Widget _avatar({double size = 44}) {
    final inicial = nombreMostrado.isNotEmpty ? nombreMostrado[0].toUpperCase() : "U";
    // _fotoUrl viene del backend como ruta relativa (/uploads/...), hay que
    // anteponer el baseUrl igual que en perfil_info_screen.dart — si no, la
    // imagen nunca carga y queda el círculo negro vacío (sin inicial).
    final tienefoto = _fotoUrl.isNotEmpty;
    final fotoCompleta = tienefoto
        ? (_fotoUrl.startsWith('http')
            ? _fotoUrl
            : '${ApiService.baseUrl}$_fotoUrl')
        : '';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colors.carbon,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: tienefoto
              ? Image.network(
                  fotoCompleta,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      inicial,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    inicial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _input({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 15, color: colors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: colors.grayMid, size: 20),
          labelText: label,
          labelStyle: TextStyle(color: colors.grayMid, fontSize: 14),
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: colors.divider, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: colors.divider, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: colors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _selectorTipo() {
    return Row(
      children: [
        Expanded(child: _selectorBtn("persona", "Persona")),
        const SizedBox(width: 8),
        Expanded(child: _selectorBtn("empresa", "Empresa")),
      ],
    );
  }

  Widget _selectorBtn(String key, String label) {
    final selected = tipoUsuario == key;
    return GestureDetector(
      onTap: () => setState(() => tipoUsuario = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.divider,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _abrirFormularioPerfil() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _formPerfil(),
      ),
    );
  }

  Widget _formPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            "Mis datos",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _selectorTipo(),
          const SizedBox(height: 16),

          if (tipoUsuario == "persona") ...[
            _input(
                label: "Nombre",
                icon: Icons.person_outline,
                controller: nombreCtrl),
            _input(
                label: "Apellidos",
                icon: Icons.person_outline,
                controller: apellidoCtrl),
            _input(
                label: "RUT",
                icon: Icons.badge_outlined,
                controller: rutCtrl),
          ],

          if (tipoUsuario == "empresa") ...[
            _input(
                label: "RUT Empresa",
                icon: Icons.business_outlined,
                controller: rutCtrl),
            _input(
                label: "Razón Social",
                icon: Icons.business_center_outlined,
                controller: razonSocialCtrl),
          ],

          _input(
              label: "Dirección",
              icon: Icons.home_outlined,
              controller: direccionCtrl),
          _input(
              label: "Comuna",
              icon: Icons.location_city_outlined,
              controller: comunaCtrl),
          _input(
              label: "Ciudad",
              icon: Icons.map_outlined,
              controller: ciudadCtrl),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "Datos bancarios",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),

          _input(
              label: "Banco",
              icon: Icons.account_balance_outlined,
              controller: bancoCtrl),
          _input(
              label: "Tipo de Cuenta",
              icon: Icons.credit_card_outlined,
              controller: tipoCuentaCtrl),
          _input(
              label: "Número de Cuenta",
              icon: Icons.numbers_outlined,
              controller: numeroCuentaCtrl,
              keyboardType: TextInputType.number),
          if (tipoUsuario == "persona")
            _input(
                label: "Correo Banco",
                icon: Icons.email_outlined,
                controller: correoBancoCtrl,
                keyboardType: TextInputType.emailAddress),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: guardarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Guardar cambios",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemFaceId() {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.face_retouching_natural_rounded,
              color: colors.textPrimary,
              size: 20,
            ),
          ),
          title: Text(
            "Face ID",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          trailing: Switch(
            value: _biometricEnabled,
            onChanged: _toggleFaceId,
            activeColor: colors.primary,
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  Widget _itemMenu(IconData icon, String titulo, VoidCallback onTap) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colors.textPrimary, size: 20),
          ),
          title: Text(
            titulo,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: colors.grayMid,
          ),
          onTap: onTap,
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  // ── MODO (claro / oscuro) ────────────────────────────────────────────
  void _abrirSelectorModo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ValueListenableBuilder<bool>(
        valueListenable: ThemeService.isDarkNotifier,
        builder: (context, isDark, __) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('MODO',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Elige cómo se ve OkVenta.',
                  style: TextStyle(fontSize: 13, color: colors.grayMid)),
              const SizedBox(height: 16),
              _opcionModo(
                icono: Icons.wb_sunny_outlined,
                titulo: 'Modo diurno',
                seleccionado: !isDark,
                onTap: () => ThemeService.setDarkMode(false),
              ),
              const SizedBox(height: 10),
              _opcionModo(
                icono: Icons.nightlight_outlined,
                titulo: 'Modo nocturno',
                seleccionado: isDark,
                onTap: () => ThemeService.setDarkMode(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcionModo({
    required IconData icono,
    required String titulo,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: seleccionado ? colors.primary.withOpacity(0.08) : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? colors.primary : colors.divider,
            width: seleccionado ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icono,
                size: 20,
                color: seleccionado ? colors.primary : colors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(titulo,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary)),
            ),
            if (seleccionado)
              Icon(Icons.check_circle_rounded, size: 20, color: colors.primary)
            else
              Icon(Icons.circle_outlined, size: 20, color: colors.grayMid),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarChatSoporte() async {
    bool abriendo = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.support_agent_rounded,
                    color: colors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Chatea con nosotros',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nuestro equipo responde a la brevedad.\nSe generará un número de caso automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.grayMid,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: abriendo
                      ? null
                      : () async {
                          if (_userId == null) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Debes iniciar sesión para chatear'),
                              ),
                            );
                            return;
                          }
                          setSheet(() => abriendo = true);
                          try {
                            final result = await ApiService
                                .crearChatDirecto(_userId!);
                            if (!mounted) return;
                            // Cerrar sheet y navegar en frame siguiente
                            // para evitar conflicto entre pop y push
                            Navigator.of(ctx).pop();
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AyudaChatScreen(
                                    ticketId:
                                        result['ticket_id'] as int,
                                    tipo: 'chat_directo',
                                    numeroReferencia:
                                        result['caso_numero'] as String?,
                                  ),
                                ),
                              );
                            });
                          } catch (_) {
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'No se pudo iniciar el chat. Intenta de nuevo.'),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: abriendo
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Iniciar chat',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              // Link a consultas anteriores
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AyudaScreen()),
                  );
                },
                child: Text(
                  'Ver mis consultas anteriores',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    await AuthService.cerrarSesion(); // Firebase + Google + SharedPreferences
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: colors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  // +30% igual que en el home (38 -> 49). Celular en modo
                  // claro, okventin en modo oscuro (sin fondo cuadrado).
                  ValueListenableBuilder<bool>(
                    valueListenable: ThemeService.isDarkNotifier,
                    builder: (_, isDark, __) {
                      return Image.asset(
                        isDark ? 'assets/images/okventin.png' : 'assets/images/home.png',
                        // Modo oscuro: mismo tamaño agrandado que en el home (57).
                        height: isDark ? 57 : 49,
                      );
                    },
                  ),
                  const Spacer(),
                  _avatar(size: 44),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mi cuenta",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (nombreMostrado.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Hola, $nombreMostrado",
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.grayMid,
                          ),
                        ),
                      ),
                    if (_userId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.tag_rounded,
                                size: 13, color: colors.grayMid),
                            const SizedBox(width: 4),
                            Text(
                              "ID de usuario: $_userId",
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.grayMid,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Avatar grande centrado
                    Center(
                      child: Stack(
                        children: [
                          _avatar(size: 80),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PerfilInfoScreen()),
                              ).then((_) => cargarDatos()),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_rounded,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card editar perfil
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PerfilInfoScreen()),
                      ).then((_) => cargarDatos()),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: colors.divider, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.edit_outlined,
                                  color: colors.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Mis datos personales",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Editar perfil y datos bancarios",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.grayMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: colors.grayMid),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Menú
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: colors.divider, width: 0.5),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _itemMenu(Icons.store_outlined, "Mis publicaciones",
                              () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const MisPublicacionesScreen()),
                            );
                          }),
                          _itemMenu(
                              Icons.handyman_outlined, "Mis servicios", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MisServiciosScreen()),
                            );
                          }),
                          _itemMenu(
                              Icons.storefront_outlined, "Mis ventas", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MisVentasScreen()),
                            );
                          }),
                          _itemMenu(
                              Icons.receipt_long_outlined, "Mis compras", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MisComprasScreen()),
                            );
                          }),
                          _itemMenu(Icons.favorite_border_rounded,
                              "Favoritos", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FavoritosScreen()),
                            );
                          }),
                          _itemMenu(
                              Icons.history_rounded, "Historial", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MisComprasScreen()),
                            );
                          }),
                          _itemMenu(
                              Icons.support_agent_rounded, "Obtener ayuda",
                              _mostrarChatSoporte),
                          _itemMenu(
                              Icons.dark_mode_outlined, "MODO", _abrirSelectorModo),
                          _itemFaceId(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Logout
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cerrarSesion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side:
                        BorderSide(color: colors.primary, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Cerrar sesión",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
