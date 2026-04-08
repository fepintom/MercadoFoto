import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';

import 'home_screen.dart';
import 'producto_detalle_screen.dart';
import '../widgets/registro_form_widget.dart';
import '../widgets/item_producto_widget.dart';

class MisPublicacionesScreen extends StatefulWidget {
  const MisPublicacionesScreen({super.key});

  @override
  State<MisPublicacionesScreen> createState() => _MisPublicacionesScreenState();
}

class _MisPublicacionesScreenState extends State<MisPublicacionesScreen> {
  List publicaciones = [];
  List publicacionesFiltradas = [];
  bool loading = true;

  String filtro = "activo"; // activo | vendido

  @override
  void initState() {
    super.initState();
    cargarPublicaciones();
  }

  // -------------------------
  // CARGAR DATA
  // -------------------------
  Future<void> cargarPublicaciones() async {
    setState(() => loading = true);

    try {
      final session = await SessionService.obtenerSesion();
      final userId = session["user_id"];
      final guestId = session["guest_id"];

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/publicaciones"),
      );

      final data = jsonDecode(response.body);

      final filtradas = (userId != null)
          ? data.where((p) => p["user_id"] == userId).toList()
          : data.where((p) => p["guest_id"] == guestId).toList();

      publicaciones = filtradas;
      aplicarFiltro();

      setState(() => loading = false);
    } catch (e) {
      debugPrint("ERROR MIS PUBLICACIONES: $e");
      setState(() => loading = false);
    }
  }

  // -------------------------
  // FILTRO
  // -------------------------
  void aplicarFiltro() {
    publicacionesFiltradas = publicaciones.where((p) {
      if (filtro == "activo") return p["estado"] != "vendido";
      if (filtro == "vendido") return p["estado"] == "vendido";
      return true;
    }).toList();
  }

  // -------------------------
  // CAMBIAR ESTADO
  // -------------------------
  Future<void> cambiarEstado(int id, String estado) async {
    try {
      await http.post(
        Uri.parse("${ApiService.baseUrl}/estado_publicacion"),
        body: {
          "publicacion_id": id.toString(),
          "estado": estado,
        },
      );

      await cargarPublicaciones();
    } catch (e) {
      debugPrint("ERROR estado: $e");
    }
  }

  // -------------------------
  // FILTROS UI
  // -------------------------
  Widget filtroTabs() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                filtro = "activo";
                aplicarFiltro();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: filtro == "activo" ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "Activos",
                  style: TextStyle(
                    color: filtro == "activo" ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                filtro = "vendido";
                aplicarFiltro();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: filtro == "vendido" ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "Vendidos",
                  style: TextStyle(
                    color: filtro == "vendido" ? Colors.white : Colors.black,
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
  // MODAL REGISTRO (RESPETADO)
  // -------------------------
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
                    color: Colors.white,
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

                          await cargarPublicaciones();
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

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// HEADER (RESPETADO)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    child: Image.asset("assets/images/logo.png", height: 40),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Mis publicaciones",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            /// FILTROS
            Padding(
              padding: const EdgeInsets.all(16),
              child: filtroTabs(),
            ),

            /// LISTA
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : publicacionesFiltradas.isEmpty
                      ? const Center(child: Text("Sin resultados"))
                      : RefreshIndicator(
                          onRefresh: cargarPublicaciones,
                          child: ListView.builder(
                            itemCount: publicacionesFiltradas.length,
                            itemBuilder: (_, i) {
                              final producto = publicacionesFiltradas[i];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductoDetalleScreen(
                                          producto: producto),
                                    ),
                                  );
                                },
                                child: ItemProductoWidget(
                                  producto: producto,
                                  onAction: (action) {
                                    if (action == "vendido") {
                                      cambiarEstado(producto["id"], "vendido");
                                    }
                                    if (action == "activar") {
                                      cambiarEstado(
                                          producto["id"], "disponible");
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
            ),

            /// BOTÓN REGISTRO
            FutureBuilder(
              future: SessionService.obtenerSesion(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final session = snapshot.data as Map;
                final userId = session["user_id"];

                if (userId != null) return const SizedBox();

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: abrirRegistroModal,
                      child: const Text("Registrarse"),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
