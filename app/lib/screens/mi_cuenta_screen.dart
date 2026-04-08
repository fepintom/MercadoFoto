import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/session_service.dart';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({super.key});

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  // -------------------------
  // CONTROLLERS
  // -------------------------
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

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  // -------------------------
  // CARGAR DATOS
  // -------------------------
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
    });
  }

  // -------------------------
  // GUARDAR DATOS
  // -------------------------
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Datos guardados")),
    );
  }

  // -------------------------
  // INPUT MODERNO
  // -------------------------
  Widget input({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // -------------------------
  // SELECTOR
  // -------------------------
  Widget selectorTipo() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => tipoUsuario = "persona"),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    tipoUsuario == "persona" ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "PERSONA",
                  style: TextStyle(
                    color:
                        tipoUsuario == "persona" ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => tipoUsuario = "empresa"),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    tipoUsuario == "empresa" ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "EMPRESA",
                  style: TextStyle(
                    color:
                        tipoUsuario == "empresa" ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------
  // ABRIR FORM
  // -------------------------
  void _abrirFormularioPerfil() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _formPerfil(),
        );
      },
    );
  }

  // -------------------------
  // FORM PERFIL
  // -------------------------
  Widget _formPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          selectorTipo(),
          const SizedBox(height: 20),
          if (tipoUsuario == "persona") ...[
            input(label: "Nombre", icon: Icons.person, controller: nombreCtrl),
            input(
                label: "Apellidos",
                icon: Icons.person_outline,
                controller: apellidoCtrl),
            input(label: "RUT", icon: Icons.badge, controller: rutCtrl),
          ],
          if (tipoUsuario == "empresa") ...[
            input(
                label: "RUT Empresa",
                icon: Icons.business,
                controller: rutCtrl),
            input(
                label: "Razón Social",
                icon: Icons.business_center,
                controller: razonSocialCtrl),
          ],
          input(
              label: "Dirección", icon: Icons.home, controller: direccionCtrl),
          input(
              label: "Comuna",
              icon: Icons.location_city,
              controller: comunaCtrl),
          input(label: "Ciudad", icon: Icons.map, controller: ciudadCtrl),
          const SizedBox(height: 10),
          input(
              label: "Banco",
              icon: Icons.account_balance,
              controller: bancoCtrl),
          input(
              label: "Tipo de Cuenta",
              icon: Icons.credit_card,
              controller: tipoCuentaCtrl),
          input(
              label: "Número de Cuenta",
              icon: Icons.confirmation_number,
              controller: numeroCuentaCtrl),
          if (tipoUsuario == "persona")
            input(
                label: "Correo Banco",
                icon: Icons.email,
                controller: correoBancoCtrl),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: guardarDatos,
              child: const Text("Guardar"),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // ITEM LISTA
  // -------------------------
  Widget itemCuenta(IconData icon, String titulo, VoidCallback onTap) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(titulo),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
        Divider(color: Colors.grey[300]),
      ],
    );
  }

  // -------------------------
  // LOGOUT
  // -------------------------
  Future<void> cerrarSesion() async {
    await SessionService.cerrarSesion();
    if (!mounted) return;
    Navigator.pop(context);
  }

  // -------------------------
  // UI PRINCIPAL
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/images/logo.png', height: 50),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Mi Cuenta",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              /// CONTENIDO
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      /// CARD PERFIL
                      GestureDetector(
                        onTap: _abrirFormularioPerfil,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.person, size: 30, color: Colors.blue),
                              SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  "Completa tus datos personales",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      itemCuenta(Icons.store, "Mis publicaciones", () {}),
                      itemCuenta(Icons.favorite, "Favoritos", () {}),
                      itemCuenta(Icons.history, "Historial", () {}),
                    ],
                  ),
                ),
              ),

              /// LOGOUT
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: cerrarSesion,
                  child: const Text("Cerrar sesión"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
