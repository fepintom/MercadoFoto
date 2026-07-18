"""Agente de soporte OkVenta (skill okventa-agentes).

Pilares:
  1. Costo: Haiku por defecto; escala a Sonnet solo cuando aporta
     (ambigüedad, disputa, frustración, o Haiku no resolvió en 2 tool calls).
  2. Seguridad: solicitar_cancelacion NUNCA cancela — devuelve una acción
     pendiente que el frontend confirma contra /support/confirm-action.
     Máximo 1 acción sensible por conversación. Toda tool valida que el
     user_id tenga permiso sobre la orden.
  3. Bitácora: cada interacción queda en agent_logs (modelo, tools, costo).
  4. Escalación: escalar_a_humano crea ticket en el sistema /ayuda existente
     (con webhook n8n). Ante cualquier error técnico, se escala — el usuario
     nunca ve un stacktrace.

Requiere ANTHROPIC_API_KEY. Sin la key, responde con degradación elegante
(deriva a ticket humano).
"""
import json
import os
import re
import secrets

from database.ordenes import obtener_orden
from database.bitacora import obtener_bitacora
from database.ayuda import crear_ticket
from database.agent_logs import registrar_log, crear_accion_pendiente
from services.mp_service import obtener_pago as mp_obtener_pago

AGENT_NAME = "soporte_general"
MODEL_RAPIDO = "claude-haiku-4-5"
MODEL_AVANZADO = "claude-sonnet-5"
# USD por millón de tokens (input, output) — precios vigentes jun-2026
PRECIOS = {
    MODEL_RAPIDO: (1.00, 5.00),
    MODEL_AVANZADO: (3.00, 15.00),
}
MAX_TOOL_ITERACIONES = 4

_FAQ_PATH = os.path.join(os.path.dirname(__file__), "..", "support", "faq.md")

SYSTEM_PROMPT = """Eres el agente de soporte de OkVenta, un marketplace chileno \
con retención de fondos (escrow) vía Mercado Pago. Respondes en español de Chile, \
cercano y claro, sin tecnicismos.

Reglas estrictas:
1. NUNCA inventes políticas ni información de OkVenta. Responde solo con lo que \
diga la FAQ (tool buscar_faq) o los datos reales de la orden/pago (tools \
consultar_orden y consultar_pago). Si la FAQ marca algo como [FALTA CONFIRMAR], \
di que el equipo lo confirmará y ofrece escalar.
2. NUNCA ejecutes cancelaciones directamente. Si el usuario quiere cancelar, usa \
solicitar_cancelacion: esa tool solo PREPARA la acción; el usuario verá un botón \
de confirmación en la app. Explícale las consecuencias (el pago retenido vuelve \
a su medio de pago) y que debe confirmar con el botón.
3. Cancelación solo es posible mientras la orden está en pago_confirmado (antes \
del despacho). Después, la vía es reportar un problema (disputa).
4. Si no puedes resolver, el usuario pide hablar con una persona, o detectas una \
disputa/reclamo que requiere mediación, usa escalar_a_humano.
5. Solo puedes consultar órdenes del propio usuario. Si pide datos de una orden \
ajena, recházalo con amabilidad.
6. Sé breve: 2-4 frases por respuesta salvo que la pregunta requiera más.
7. Nunca confirmes que una acción se ejecutó si la tool no devolvió éxito."""

TOOLS = [
    {
        "name": "buscar_faq",
        "description": "Busca en la base de conocimiento oficial de OkVenta "
                       "(pagos, escrow, entregas, cancelaciones, disputas, "
                       "publicar, servicios). Úsala SIEMPRE antes de responder "
                       "preguntas sobre cómo funciona OkVenta.",
        "input_schema": {
            "type": "object",
            "properties": {"query": {"type": "string",
                                     "description": "Pregunta o palabras clave"}},
            "required": ["query"],
        },
    },
    {
        "name": "consultar_orden",
        "description": "Estado real de una orden del usuario: estado, montos, "
                       "fechas, método de entrega e historial de eventos. Úsala "
                       "para '¿dónde está mi pedido?' o cualquier consulta de una "
                       "orden específica.",
        "input_schema": {
            "type": "object",
            "properties": {"order_id": {"type": "integer"}},
            "required": ["order_id"],
        },
    },
    {
        "name": "consultar_pago",
        "description": "Estado del pago de una orden en Mercado Pago (aprobado, "
                       "pendiente, rechazado, reembolsado). Úsala para preguntas "
                       "sobre el pago o la liberación de fondos.",
        "input_schema": {
            "type": "object",
            "properties": {"order_id": {"type": "integer"}},
            "required": ["order_id"],
        },
    },
    {
        "name": "solicitar_cancelacion",
        "description": "Prepara la cancelación de una orden (NO la ejecuta). Solo "
                       "válida si la orden está en pago_confirmado y pertenece al "
                       "usuario. El usuario deberá confirmar con un botón en la app.",
        "input_schema": {
            "type": "object",
            "properties": {
                "order_id": {"type": "integer"},
                "motivo": {"type": "string"},
            },
            "required": ["order_id", "motivo"],
        },
    },
    {
        "name": "escalar_a_humano",
        "description": "Crea un ticket para que el equipo OkVenta atienda "
                       "personalmente. Úsala si no puedes resolver, si el usuario "
                       "lo pide, o ante disputas que requieren mediación.",
        "input_schema": {
            "type": "object",
            "properties": {
                "motivo": {"type": "string"},
                "resumen": {"type": "string",
                            "description": "Resumen de la conversación para el equipo"},
            },
            "required": ["motivo", "resumen"],
        },
    },
]

_SENALES_SONNET = (
    "disputa", "reclamo", "estafa", "denuncia", "abogado", "sernac",
    "fraude", "robo", "no me sirve", "pésimo", "pesimo", "indignante",
    "furioso", "molesto", "enojado", "tercera vez", "de nuevo", "otra vez",
    "nadie me responde", "urgente",
)


def _cargar_faq() -> str:
    try:
        with open(_FAQ_PATH, encoding="utf-8") as f:
            return f.read()
    except Exception:
        return ""


def _buscar_faq(query: str) -> str:
    """Búsqueda simple por solapamiento de palabras sobre secciones ### del FAQ."""
    faq = _cargar_faq()
    if not faq:
        return "FAQ no disponible."
    secciones = re.split(r"\n(?=### )", faq)
    palabras = {p for p in re.findall(r"\w+", query.lower()) if len(p) > 3}
    puntuadas = []
    for s in secciones:
        texto = s.lower()
        score = sum(1 for p in palabras if p in texto)
        if score:
            puntuadas.append((score, s))
    puntuadas.sort(key=lambda x: -x[0])
    top = [s for _, s in puntuadas[:3]]
    return "\n\n---\n\n".join(top) if top else \
        "No encontré nada en la FAQ sobre eso. Considera escalar a un humano."


def _permiso_sobre_orden(orden: dict, user_id: int) -> bool:
    return user_id in (orden.get("comprador_id"), orden.get("vendedor_id"))


def _consultar_orden(order_id: int, user_id: int) -> str:
    orden = obtener_orden(order_id)
    if not orden:
        return f"La orden #{order_id} no existe."
    if not _permiso_sobre_orden(orden, user_id):
        return ("PERMISO_DENEGADO: esta orden no pertenece al usuario. "
                "No entregues ningún dato de ella.")
    rol = "comprador" if user_id == orden["comprador_id"] else "vendedor"
    eventos = obtener_bitacora(order_id)
    historial = "; ".join(
        f"{e['created_at']} {e['evento']}" for e in eventos[-6:]) or "sin eventos"
    return json.dumps({
        "orden_id": orden["id"],
        "rol_del_usuario": rol,
        "titulo": orden["titulo"],
        "estado": orden["estado"],
        "monto": orden["monto"],
        "tipo": orden["tipo"],
        "metodo_entrega": orden.get("delivery_method"),
        "creada": orden.get("created_at"),
        "entrega_reportada_en": orden.get("entrega_reportada_en"),
        "historial_reciente": historial,
    }, ensure_ascii=False)


def _consultar_pago(order_id: int, user_id: int) -> str:
    orden = obtener_orden(order_id)
    if not orden:
        return f"La orden #{order_id} no existe."
    if not _permiso_sobre_orden(orden, user_id):
        return "PERMISO_DENEGADO: esta orden no pertenece al usuario."
    payment_id = orden.get("mp_payment_id")
    if not payment_id:
        return json.dumps({"estado_pago": "sin_pago_registrado",
                           "estado_orden": orden["estado"]}, ensure_ascii=False)
    if orden.get("es_test") or str(payment_id).startswith("TEST-"):
        return json.dumps({"estado_pago": "aprobado (modo prueba, simulado)",
                           "monto": orden["monto"],
                           "estado_orden": orden["estado"]}, ensure_ascii=False)
    try:
        pago = mp_obtener_pago(payment_id)
        return json.dumps({"estado_pago": pago.get("status"),
                           "detalle": pago.get("status_detail"),
                           "monto": pago.get("transaction_amount"),
                           "estado_orden": orden["estado"]}, ensure_ascii=False)
    except Exception:
        return ("No pude consultar Mercado Pago en este momento. "
                "Sugiere reintentar o escala a un humano.")


def _solicitar_cancelacion(order_id: int, motivo: str, user_id: int,
                           estado_conv: dict):
    """Devuelve (texto_para_el_modelo, accion_pendiente | None)."""
    if estado_conv.get("accion_sensible_usada"):
        return ("LIMITE: ya se preparó una acción sensible en esta conversación. "
                "No prepares otra; sugiere continuar con la que está pendiente "
                "o escalar a un humano."), None
    orden = obtener_orden(order_id)
    if not orden:
        return f"La orden #{order_id} no existe.", None
    if user_id != orden.get("comprador_id"):
        return ("PERMISO_DENEGADO: solo el comprador de la orden puede "
                "solicitar su cancelación."), None
    if orden["estado"] != "pago_confirmado":
        return (f"NO_CANCELABLE: la orden está en estado '{orden['estado']}'. "
                "Solo se puede cancelar en pago_confirmado (antes del despacho). "
                "Si ya está en camino o entregada, la vía es reportar un "
                "problema (disputa)."), None
    token = secrets.token_urlsafe(16)
    crear_accion_pendiente(token, "cancelar_orden", order_id, user_id, motivo)
    estado_conv["accion_sensible_usada"] = True
    accion = {
        "tipo": "cancelar_orden",
        "action_token": token,
        "orden_id": order_id,
        "titulo": orden["titulo"],
        # Monto desde la fuente de verdad, nunca calculado por el modelo
        "monto": orden["monto"],
    }
    return (f"ACCION_PREPARADA: cancelación de la orden #{order_id} "
            f"('{orden['titulo']}', ${orden['monto']:,.0f}) lista para que el "
            "usuario la confirme con el botón que verá en el chat. Explícale "
            "que al confirmar, el pago retenido vuelve a su medio de pago."), accion


def _escalar_a_humano(motivo: str, resumen: str, user_id: int, order_id,
                      notificar_n8n=None) -> str:
    detalle = f"[Agente de soporte] {motivo}\n\nResumen: {resumen}"
    ticket = crear_ticket(user_id, "agente_soporte",
                          str(order_id) if order_id else "", detalle)
    if notificar_n8n:
        try:
            notificar_n8n(ticket["id"], user_id, "agente_soporte",
                          str(order_id) if order_id else "", detalle)
        except Exception:
            pass
    return (f"TICKET_CREADO: #{ticket['id']}. Dile al usuario que el equipo "
            "OkVenta ya fue notificado y le responderá por la sección Ayuda.")


def _necesita_sonnet(mensaje: str, historial: list) -> bool:
    m = (mensaje or "").lower()
    if any(s in m for s in _SENALES_SONNET):
        return True
    # Pregunta repetida: mismo mensaje (aprox) ya enviado antes
    previos = [h.get("content", "") for h in historial if h.get("role") == "user"]
    if any(p.strip().lower() == m.strip() for p in previos if isinstance(p, str)):
        return True
    # Conversación larga sin resolver
    return len(previos) >= 4


def _costo_usd(modelo: str, in_tok: int, out_tok: int) -> float:
    pin, pout = PRECIOS.get(modelo, PRECIOS[MODEL_RAPIDO])
    return (in_tok * pin + out_tok * pout) / 1_000_000


def _ejecutar_tool(nombre, args, user_id, order_id, estado_conv, notificar_n8n):
    """Ejecuta una tool; devuelve (resultado_str, tipo_resultado, accion|None)."""
    if nombre == "buscar_faq":
        return _buscar_faq(args.get("query", "")), None, None
    if nombre == "consultar_orden":
        return _consultar_orden(int(args.get("order_id", 0)), user_id), None, None
    if nombre == "consultar_pago":
        return _consultar_pago(int(args.get("order_id", 0)), user_id), None, None
    if nombre == "solicitar_cancelacion":
        texto, accion = _solicitar_cancelacion(
            int(args.get("order_id", 0)), args.get("motivo", ""), user_id, estado_conv)
        return texto, ("accion_pendiente_confirmacion" if accion else None), accion
    if nombre == "escalar_a_humano":
        texto = _escalar_a_humano(args.get("motivo", ""), args.get("resumen", ""),
                                  user_id, order_id, notificar_n8n)
        return texto, "escalado_humano", None
    return f"Tool desconocida: {nombre}", None, None


def _loop_con_modelo(client, modelo, mensajes, user_id, order_id,
                     estado_conv, notificar_n8n):
    """Corre el loop de tool use con un modelo. Devuelve dict con el resultado."""
    tools_usadas = []
    costo = 0.0
    resultado = "resuelto"
    accion = None
    texto_final = None

    for _ in range(MAX_TOOL_ITERACIONES):
        resp = client.messages.create(
            model=modelo,
            max_tokens=1024,
            system=[{"type": "text", "text": SYSTEM_PROMPT,
                     "cache_control": {"type": "ephemeral"}}],
            tools=TOOLS,
            messages=mensajes,
        )
        costo += _costo_usd(modelo, resp.usage.input_tokens, resp.usage.output_tokens)

        if resp.stop_reason != "tool_use":
            texto_final = next(
                (b.text for b in resp.content if b.type == "text"), "")
            break

        mensajes.append({"role": "assistant", "content": resp.content})
        tool_results = []
        for block in resp.content:
            if block.type != "tool_use":
                continue
            tools_usadas.append(block.name)
            salida, tipo, acc = _ejecutar_tool(
                block.name, block.input or {}, user_id, order_id,
                estado_conv, notificar_n8n)
            if tipo:
                resultado = tipo
            if acc:
                accion = acc
            tool_results.append({"type": "tool_result",
                                 "tool_use_id": block.id,
                                 "content": salida})
        mensajes.append({"role": "user", "content": tool_results})

    return {"texto": texto_final, "tools": tools_usadas, "costo": costo,
            "resultado": resultado, "accion": accion, "resuelto": texto_final is not None}


def chat(user_id: int, message: str, order_id=None, conversation_history=None,
         notificar_n8n=None) -> dict:
    """Punto de entrada del agente. Siempre devuelve una respuesta amigable."""
    historial = conversation_history or []
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")

    # Degradación elegante sin API key: derivar directo a humano.
    if not api_key:
        texto = _escalar_a_humano(
            "Agente IA no disponible (sin ANTHROPIC_API_KEY)",
            f"Consulta del usuario: {message}", user_id, order_id, notificar_n8n)
        registrar_log(AGENT_NAME, user_id, order_id, "ninguno", message,
                      [], "escalado_humano", 0.0, "Sin API key; ticket creado")
        return {"reply": "En este momento el asistente automático no está "
                         "disponible, pero creamos un ticket y el equipo "
                         "OkVenta te responderá pronto por la sección Ayuda.",
                "resultado": "escalado_humano", "modelo": "ninguno"}

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)

        contexto = f"[Contexto: user_id={user_id}"
        if order_id:
            contexto += f", el usuario está viendo la orden #{order_id}"
        contexto += "]"

        mensajes = []
        for h in historial[-10:]:
            if h.get("role") in ("user", "assistant") and h.get("content"):
                mensajes.append({"role": h["role"], "content": str(h["content"])})
        mensajes.append({"role": "user", "content": f"{contexto}\n{message}"})

        estado_conv = {"accion_sensible_usada": any(
            "confirmar" in str(h.get("content", "")).lower() and
            h.get("role") == "assistant" for h in historial)}

        modelo = MODEL_AVANZADO if _necesita_sonnet(message, historial) else MODEL_RAPIDO
        out = _loop_con_modelo(client, modelo, list(mensajes), user_id, order_id,
                               estado_conv, notificar_n8n)
        costo = out["costo"]

        # Haiku no cerró en N iteraciones → reintenta el turno con Sonnet
        if not out["resuelto"] and modelo == MODEL_RAPIDO:
            modelo = MODEL_AVANZADO
            out2 = _loop_con_modelo(client, modelo, list(mensajes), user_id,
                                    order_id, estado_conv, notificar_n8n)
            costo += out2["costo"]
            out2["costo"] = costo
            out2["tools"] = out["tools"] + out2["tools"]
            out = out2

        texto = out["texto"] or ("Estoy teniendo problemas para resolver esto. "
                                 "¿Quieres que te contacte con una persona del equipo?")
        registrar_log(AGENT_NAME, user_id, order_id, modelo, message,
                      out["tools"], out["resultado"], round(costo, 6),
                      (texto[:140] if texto else ""))
        respuesta = {"reply": texto, "resultado": out["resultado"], "modelo": modelo}
        if out["accion"]:
            respuesta["requires_confirmation"] = True
            respuesta["action"] = out["accion"]
        return respuesta

    except Exception as e:
        # El usuario nunca ve un error técnico: se escala automáticamente.
        try:
            _escalar_a_humano(f"Error técnico del agente: {type(e).__name__}",
                              f"Consulta: {message}", user_id, order_id,
                              notificar_n8n)
        except Exception:
            pass
        registrar_log(AGENT_NAME, user_id, order_id, "error", message,
                      [], "error", 0.0, str(e)[:200])
        return {"reply": "Tuve un problema procesando tu consulta, así que le "
                         "avisé al equipo OkVenta para que te ayude "
                         "personalmente. Te responderán por la sección Ayuda.",
                "resultado": "error", "modelo": "ninguno"}
