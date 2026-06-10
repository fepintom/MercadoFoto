import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'ayuda_screen.dart';
import 'mis_compras_screen.dart';
import 'mis_publicaciones_screen.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Face ID no está disponible. Verifica que esté configurado en Ajustes del dispositivo."),
          backgroundColor: AppColors.carbon,
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
      const SnackBar(
        content: Text("Datos guardados correctamente"),
        backgroundColor: AppColors.carbon,
      ),
    );
    await cargarDatos();
  }

  Widget _avatar({double size = 44}) {
    final inicial = nombreMostrado.isNotEmpty ? nombreMostrado[0].toUpperCase() : "U";
    final tienefoto = _fotoUrl.isNotEmpty;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.carbon,
      backgroundImage: tienefoto ? NetworkImage(_fotoUrl) : null,
      onBackgroundImageError: tienefoto ? (_, __) {} : null,
      child: tienefoto
          ? null
          : Text(
              inicial,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
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
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.grayMid, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.grayMid, fontSize: 14),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.divider, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.divider, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
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
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textSecondary,
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
      backgroundColor: AppColors.surface,
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
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            "Mis datos",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "Datos bancarios",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
                backgroundColor: AppColors.primary,
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
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              color: AppColors.carbon,
              size: 20,
            ),
          ),
          title: const Text(
            "Face ID",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Switch(
            value: _biometricEnabled,
            onChanged: _toggleFaceId,
            activeColor: AppColors.primary,
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
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.carbon, size: 20),
          ),
          title: Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.grayMid,
          ),
          onTap: onTap,
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.carbon),
                  ),
                  const SizedBox(width: 12),
                  Image.asset('assets/images/logo.png', height: 38),
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
                    const Text(
                      "Mi cuenta",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (nombreMostrado.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Hola, $nombreMostrado",
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.grayMid,
                          ),
                        ),
                      ),
                    if (_userId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.tag_rounded,
                                size: 13, color: AppColors.grayMid),
                            const SizedBox(width: 4),
                            Text(
                              "ID de usuario: $_userId",
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grayMid,
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
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.divider, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.edit_outlined,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Mis datos personales",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Editar perfil y datos bancarios",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grayMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: AppColors.grayMid),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Menú
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.divider, width: 0.5),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _itemMenu(Icons.store_outlined, "Mis publicaciones",
                              () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const MisPublicacionesScreen()),
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
                              "Favoritos", () {}),
                          _itemMenu(
                              Icons.history_rounded, "Historial", () {}),
                          _itemMenu(
                              Icons.support_agent_rounded, "Obtener ayuda",
                              () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const AyudaScreen()),
                                  )),
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
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1),
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
