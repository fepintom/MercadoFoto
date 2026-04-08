import 'package:flutter/material.dart';

class RegistroFormWidget extends StatefulWidget {
  final Function(String email, String password) onSubmit;
  final bool isLogin;
  final VoidCallback? onToggle;

  const RegistroFormWidget({
    super.key,
    required this.onSubmit,
    this.isLogin = false,
    this.onToggle,
  });

  @override
  State<RegistroFormWidget> createState() => _RegistroFormWidgetState();
}

class _RegistroFormWidgetState extends State<RegistroFormWidget> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;

  void submit() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (!email.contains("@")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un correo válido")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña debe tener al menos 6 caracteres"),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await widget.onSubmit(email, password);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.isLogin ? "Ingresar" : "Crear cuenta";
    final textoBoton = widget.isLogin ? "Ingresar" : "Registrarse";

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        /// HANDLE
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        const SizedBox(height: 20),

        /// HEADER
        Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 30,
            ),
            Expanded(
              child: Center(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),

        const SizedBox(height: 20),

        /// EMAIL
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Correo",
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 15),

        /// PASSWORD
        TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Contraseña",
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        /// BOTÓN
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: loading ? null : submit,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(textoBoton),
          ),
        ),

        const SizedBox(height: 10),

        /// 🔥 TOGGLE LOGIN / REGISTRO
        Center(
          child: TextButton(
            onPressed: widget.onToggle,
            child: Text(
              widget.isLogin
                  ? "¿No tienes cuenta? Regístrate"
                  : "¿Ya tienes cuenta? Ingresa",
            ),
          ),
        ),

        const SizedBox(height: 10),

        /// DIVISOR
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text("o"),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),

        const SizedBox(height: 15),

        /// GOOGLE
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              // TODO: Google login
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              backgroundColor: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  "https://developers.google.com/identity/images/g-logo.png",
                  height: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  "Continuar con Google",
                  style: TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
