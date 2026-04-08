import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/registro_form_widget.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final Map producto;

  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  bool campoEstado = false;
  bool campoCodigo = false;
  bool campoSKU = false;
  bool campoStock = false;

  int? userId;

  final estadoController = TextEditingController();
  final codigoController = TextEditingController();
  final skuController = TextEditingController();
  final stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargarSesion();
  }

  Future<void> cargarSesion() async {
    final id = await SessionService.obtenerUser();
    if (!mounted) return;
    setState(() {
      userId = id;
    });
  }

  String safeDecode(String text) {
    try {
      return utf8.decode(text.codeUnits);
    } catch (_) {
      return text;
    }
  }

  Widget campoExpandible({
    required String titulo,
    required bool abierto,
    required VoidCallback toggle,
    TextEditingController? controller,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Icon(
                  abierto ? Icons.remove : Icons.add,
                  color: AppColors.grayMid,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (abierto)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.divider, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.divider, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  void abrirRegistroModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: RegistroFormWidget(
                    onSubmit: (email, password) async {
                      try {
                        final guestId = await SessionService.obtenerGuest();
                        final response = await http.post(
                          Uri.parse("${ApiService.baseUrl}/registro"),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({
                            "email": email,
                            "password": password,
                            "guest_id": guestId,
                          }),
                        );
                        final data = jsonDecode(response.body);
                        if (response.statusCode == 200) {
                          await SessionService.guardarUser(data["user_id"]);
                          await SessionService.guardarNombre(data["nombre"]);
                          await SessionService.guardarGuest("");
                          Navigator.pop(context);
                          if (!mounted) return;
                          setState(() {});
                        }
                      } catch (e) {
                        debugPrint("ERROR REGISTRO: $e");
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagen = "${ApiService.baseUrl}${widget.producto["imagen_url"]}";
    final titulo = widget.producto["titulo"] ?? "";
    final descripcion = widget.producto["descripcion"] ?? "";
    final precio = widget.producto["precio"] ?? 0;
    final dimensiones = widget.producto["dimensiones"];

    final int? ownerId = widget.producto["user_id"];
    final bool esInvitado = userId == null;
    final bool esDueno = userId != null && userId == ownerId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Detalle del producto",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.divider, height: 0.5),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGEN ───────────────────────────────────────────
            Image.network(
              imagen,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 300,
                color: AppColors.background,
                child: const Icon(Icons.image_not_supported,
                    color: AppColors.grayMid, size: 48),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── TÍTULO ───────────────────────────────────
                  Text(
                    safeDecode(titulo),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── DESCRIPCIÓN ──────────────────────────────
                  Text(
                    safeDecode(descripcion),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── PRECIO ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Text(
                      "\$${precio.toString()}",
                      style: const TextStyle(
                        fontSize: 26,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 20),

                  // ── DIMENSIONES ──────────────────────────────
                  // Solo visible para usuarios registrados
                  if (!esInvitado &&
                      dimensiones != null &&
                      dimensiones.toString().isNotEmpty &&
                      dimensiones.toString() != "No determinado")
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten,
                              size: 18, color: AppColors.grayMid),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Dimensiones estimadas",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grayMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dimensiones.toString(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Si es invitado y hay dimensiones → mostrar candado
                  if (esInvitado &&
                      dimensiones != null &&
                      dimensiones.toString().isNotEmpty &&
                      dimensiones.toString() != "No determinado")
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 18, color: AppColors.grayMid),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Regístrate para ver las dimensiones del producto",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.grayMid,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── INFORMACIÓN ADICIONAL ─────────────────────
                  const Text(
                    "Información adicional",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  campoExpandible(
                    titulo: "Nuevo / Usado",
                    abierto: campoEstado,
                    controller: estadoController,
                    toggle: () => setState(() => campoEstado = !campoEstado),
                  ),
                  campoExpandible(
                    titulo: "Código universal",
                    abierto: campoCodigo,
                    controller: codigoController,
                    toggle: () => setState(() => campoCodigo = !campoCodigo),
                  ),
                  campoExpandible(
                    titulo: "SKU",
                    abierto: campoSKU,
                    controller: skuController,
                    toggle: () => setState(() => campoSKU = !campoSKU),
                  ),
                  campoExpandible(
                    titulo: "Stock",
                    abierto: campoStock,
                    controller: stockController,
                    toggle: () => setState(() => campoStock = !campoStock),
                  ),

                  const SizedBox(height: 30),

                  // ── BOTONES DE ACCIÓN ─────────────────────────
                  if (esInvitado)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: abrirRegistroModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Registrarse para contactar",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  if (!esInvitado && !esDueno)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Contactar vendedor",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  if (esDueno)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.carbon,
                              foregroundColor: AppColors.textOnPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Editar publicación",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Eliminar publicación",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
