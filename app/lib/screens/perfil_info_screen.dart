import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class PerfilInfoScreen extends StatefulWidget {
  const PerfilInfoScreen({super.key});

  @override
  State<PerfilInfoScreen> createState() => _PerfilInfoScreenState();
}

class _PerfilInfoScreenState extends State<PerfilInfoScreen> {
  // ── Datos locales ─────────────────────────────────────────────────────────
  String _nombre        = "";
  String _apellido      = "";
  String _rut           = "";
  String _email         = "";
  String _telefono      = "";
  String _username      = "";

  // Dirección
  String _direccion     = "";
  String _comuna        = "";
  String _ciudad        = "";

  // Datos bancarios
  String _banco         = "";
  String _tipoCuenta    = "";
  String _numeroCuenta  = "";
  String _correoBanco   = "";

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nombre       = p.getString("nombre")        ?? "";
      _apellido     = p.getString("apellido")      ?? "";
      _rut          = p.getString("rut")           ?? "";
      _email        = p.getString("email")         ?? "";
      _telefono     = p.getString("telefono")      ?? "";
      _username     = p.getString("username")      ?? _generarUsername();
      _direccion    = p.getString("direccion")     ?? "";
      _comuna       = p.getString("comuna")        ?? "";
      _ciudad       = p.getString("ciudad")        ?? "";
      _banco        = p.getString("banco")         ?? "";
      _tipoCuenta   = p.getString("tipo_cuenta")   ?? "";
      _numeroCuenta = p.getString("numero_cuenta") ?? "";
      _correoBanco  = p.getString("correo_banco")  ?? "";
    });
  }

  String _generarUsername() {
    if (_nombre.isNotEmpty) {
      return (_nombre.substring(0, _nombre.length > 4 ? 4 : _nombre.length) +
              (_apellido.isNotEmpty ? _apellido.substring(0, 2) : ""))
          .toUpperCase();
    }
    return "";
  }

  Future<void> _guardarCampo(String clave, String valor) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(clave, valor);
  }

  // ── Diálogo de edición ────────────────────────────────────────────────────
  void _editarCampo({
    required String titulo,
    required String valorActual,
    required String hint,
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter> formatters = const [],
    required Future<void> Function(String) onGuardar,
  }) {
    final ctrl = TextEditingController(text: valorActual);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: teclado,
              inputFormatters: formatters,
              autofocus: true,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(color: AppColors.grayMid, fontSize: 14),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
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
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onGuardar(ctrl.text.trim());
                  await _cargarDatos();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Guardar",
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fila de dato ──────────────────────────────────────────────────────────
  Widget _fila({
    required IconData icon,
    required String valor,
    required String sublabel,
    bool verificado = false,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final estaCompleto = valor.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(14))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icono
                Icon(icon, size: 22, color: AppColors.grayMid),
                const SizedBox(width: 14),

                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estaCompleto ? valor : "Sin información",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: estaCompleto
                              ? AppColors.textPrimary
                              : AppColors.grayMid,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grayMid,
                            height: 1.3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Badge verificado
                if (verificado && estaCompleto)
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white),
                  ),

                // Chevron
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.grayMid),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1, thickness: 0.5, indent: 54, color: AppColors.divider),
      ],
    );
  }

  // ── Encabezado de sección ─────────────────────────────────────────────────
  Widget _seccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final nombreCompleto =
        [_nombre, _apellido].where((s) => s.isNotEmpty).join(" ");

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 24, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Información de tu perfil",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Puedes agregar, modificar o corregir tu información personal y los datos de la cuenta.",
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.grayMid,
                    height: 1.4),
              ),
            ),

            // ── Contenido scrollable ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── SECCIÓN: Información personal ──────────────
                    _seccion("Información personal"),
                    _card([
                      _fila(
                        icon: Icons.badge_outlined,
                        valor: nombreCompleto,
                        sublabel: "Nombre y apellido.",
                        verificado: true,
                        onTap: () => _editarNombreCompleto(),
                      ),
                      _fila(
                        icon: Icons.assignment_ind_outlined,
                        valor: _rut,
                        sublabel: "Número de documento.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Número de documento",
                          valorActual: _rut,
                          hint: "12.345.678-9",
                          onGuardar: (v) async {
                            setState(() => _rut = v);
                            await _guardarCampo("rut", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.face_outlined,
                        valor: _username,
                        sublabel: "Nombre elegido.",
                        verificado: false,
                        isLast: true,
                        onTap: () => _editarCampo(
                          titulo: "Nombre elegido",
                          valorActual: _username,
                          hint: "Tu apodo o nombre público",
                          onGuardar: (v) async {
                            setState(() => _username = v);
                            await _guardarCampo("username", v);
                          },
                        ),
                      ),
                    ]),

                    // ── SECCIÓN: Datos de la cuenta ────────────────
                    _seccion("Datos de la cuenta"),
                    _card([
                      _fila(
                        icon: Icons.mail_outline_rounded,
                        valor: _email,
                        sublabel: "E-mail donde recibes comunicaciones.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Correo electrónico",
                          valorActual: _email,
                          hint: "tucorreo@ejemplo.com",
                          teclado: TextInputType.emailAddress,
                          onGuardar: (v) async {
                            setState(() => _email = v);
                            await _guardarCampo("email", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.phone_outlined,
                        valor: _telefono.isNotEmpty
                            ? (_telefono.startsWith("+")
                                ? _telefono
                                : "+56$_telefono")
                            : "",
                        sublabel:
                            "Número donde recibes códigos de verificación y comunicaciones.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Número de teléfono",
                          valorActual: _telefono,
                          hint: "+56912345678",
                          teclado: TextInputType.phone,
                          onGuardar: (v) async {
                            setState(() => _telefono = v);
                            await _guardarCampo("telefono", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.person_outline_rounded,
                        valor: _username.isNotEmpty
                            ? _username.toUpperCase()
                            : "",
                        sublabel: "Nombre de usuario.",
                        verificado: false,
                        isLast: true,
                        onTap: () => _editarCampo(
                          titulo: "Nombre de usuario",
                          valorActual: _username,
                          hint: "TUUSUARIO",
                          onGuardar: (v) async {
                            setState(() => _username = v.toUpperCase());
                            await _guardarCampo("username", v.toUpperCase());
                          },
                        ),
                      ),
                    ]),

                    // ── SECCIÓN: Dirección ────────────────────────
                    _seccion("Dirección"),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.15),
                            width: 0.5),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 15, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Esta dirección define el radio de tus publicaciones en el mapa. Los compradores verán un círculo de 2 km alrededor de ella.",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _card([
                      _fila(
                        icon: Icons.home_outlined,
                        valor: _direccion,
                        sublabel: "Calle y número.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Dirección",
                          valorActual: _direccion,
                          hint: "Ej: Av. Providencia 1234",
                          onGuardar: (v) async {
                            setState(() => _direccion = v);
                            await _guardarCampo("direccion", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.location_city_outlined,
                        valor: _comuna,
                        sublabel: "Comuna.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Comuna",
                          valorActual: _comuna,
                          hint: "Ej: Providencia",
                          onGuardar: (v) async {
                            setState(() => _comuna = v);
                            await _guardarCampo("comuna", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.map_outlined,
                        valor: _ciudad,
                        sublabel: "Ciudad.",
                        verificado: true,
                        isLast: true,
                        onTap: () => _editarCampo(
                          titulo: "Ciudad",
                          valorActual: _ciudad,
                          hint: "Ej: Santiago",
                          onGuardar: (v) async {
                            setState(() => _ciudad = v);
                            await _guardarCampo("ciudad", v);
                          },
                        ),
                      ),
                    ]),

                    // ── SECCIÓN: Datos bancarios ───────────────────
                    _seccion("Datos bancarios"),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.carbon.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.divider, width: 0.5),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 15, color: AppColors.grayMid),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Tus datos bancarios son privados y solo se usan para recibir pagos por tus ventas.",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grayMid,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _card([
                      _fila(
                        icon: Icons.account_balance_outlined,
                        valor: _banco,
                        sublabel: "Banco donde recibes tus pagos.",
                        verificado: true,
                        onTap: () => _abrirSelectorBanco(),
                      ),
                      _fila(
                        icon: Icons.credit_card_outlined,
                        valor: _tipoCuenta,
                        sublabel: "Tipo de cuenta bancaria.",
                        verificado: true,
                        onTap: () => _abrirSelectorTipoCuenta(),
                      ),
                      _fila(
                        icon: Icons.numbers_outlined,
                        valor: _numeroCuenta,
                        sublabel: "Número de cuenta.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Número de cuenta",
                          valorActual: _numeroCuenta,
                          hint: "00000000000",
                          teclado: TextInputType.number,
                          onGuardar: (v) async {
                            setState(() => _numeroCuenta = v);
                            await _guardarCampo("numero_cuenta", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.email_outlined,
                        valor: _correoBanco,
                        sublabel: "Correo asociado a la cuenta.",
                        verificado: true,
                        isLast: true,
                        onTap: () => _editarCampo(
                          titulo: "Correo del banco",
                          valorActual: _correoBanco,
                          hint: "tucorreo@banco.cl",
                          teclado: TextInputType.emailAddress,
                          onGuardar: (v) async {
                            setState(() => _correoBanco = v);
                            await _guardarCampo("correo_banco", v);
                          },
                        ),
                      ),
                    ]),

                    // ── Footer privacidad ──────────────────────────
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 16,
                            color: AppColors.grayMid),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grayMid,
                                  height: 1.5),
                              children: [
                                const TextSpan(
                                  text:
                                      "Tu información personal está siempre protegida. Si tienes dudas, puedes consultar ",
                                ),
                                TextSpan(
                                  text: "cómo cuidamos tus datos.",
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card contenedor de filas ──────────────────────────────────────────────
  Widget _card(List<Widget> filas) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: filas),
    );
  }

  // ── Editar nombre y apellido juntos ───────────────────────────────────────
  void _editarNombreCompleto() {
    final nombreCtrl   = TextEditingController(text: _nombre);
    final apellidoCtrl = TextEditingController(text: _apellido);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Nombre y apellido",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            _campoEdicion(nombreCtrl, "Nombre", autofocus: true),
            const SizedBox(height: 10),
            _campoEdicion(apellidoCtrl, "Apellido(s)"),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final n = nombreCtrl.text.trim();
                  final a = apellidoCtrl.text.trim();
                  Navigator.pop(context);
                  setState(() { _nombre = n; _apellido = a; });
                  await _guardarCampo("nombre", n);
                  await _guardarCampo("apellido", a);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Guardar",
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selector banco ────────────────────────────────────────────────────────
  void _abrirSelectorBanco() {
    const bancos = [
      "Banco de Chile", "BancoEstado", "Santander", "BCI", "Scotiabank",
      "Itaú", "BICE", "Banco Security", "Falabella", "Ripley",
      "HSBC", "Coopeuch", "Tenpo", "Mercado Pago",
    ];
    _abrirSelectorOpciones(
      titulo: "Selecciona tu banco",
      opciones: bancos,
      valorActual: _banco,
      onSeleccionar: (v) async {
        setState(() => _banco = v);
        await _guardarCampo("banco", v);
      },
    );
  }

  void _abrirSelectorTipoCuenta() {
    const tipos = [
      "Cuenta Corriente",
      "Cuenta Vista / RUT",
      "Cuenta de Ahorro",
      "Cuenta Digital",
    ];
    _abrirSelectorOpciones(
      titulo: "Tipo de cuenta",
      opciones: tipos,
      valorActual: _tipoCuenta,
      onSeleccionar: (v) async {
        setState(() => _tipoCuenta = v);
        await _guardarCampo("tipo_cuenta", v);
      },
    );
  }

  void _abrirSelectorOpciones({
    required String titulo,
    required List<String> opciones,
    required String valorActual,
    required Future<void> Function(String) onSeleccionar,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(titulo,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            const Divider(height: 1, thickness: 0.5),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: opciones.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, thickness: 0.5, indent: 20, endIndent: 20),
                itemBuilder: (_, i) {
                  final op = opciones[i];
                  final sel = op == valorActual;
                  return ListTile(
                    title: Text(op,
                        style: TextStyle(
                            fontSize: 15,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal)),
                    trailing: sel
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      await onSeleccionar(op);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _campoEdicion(TextEditingController ctrl, String hint,
      {bool autofocus = false}) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.grayMid, fontSize: 14),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
