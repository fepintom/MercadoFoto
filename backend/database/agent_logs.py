"""Bitácora obligatoria de los agentes de IA de OkVenta.

Un documento por interacción (esquema base del skill okventa-agentes) para
auditar volumen, % resuelto sin humano, costo y preguntas mal resueltas.
También guarda las acciones sensibles pendientes de confirmación (guardrail:
el agente nunca ejecuta directo; el usuario confirma y un endpoint separado
ejecuta).
"""
import json
import sqlite3
from config import PUBLICACIONES_DB as DB


def init_agent_logs_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS agent_logs (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        agent_name         TEXT NOT NULL,
        user_id            INTEGER,
        order_id           INTEGER,
        modelo_usado       TEXT,
        mensaje_usuario    TEXT,
        tools_llamadas     TEXT,   -- JSON list
        resultado          TEXT,   -- resuelto | escalado_humano | accion_pendiente_confirmacion | accion_ejecutada | error
        costo_estimado_usd REAL,
        resumen            TEXT
    )
    """)
    c.execute("""
    CREATE TABLE IF NOT EXISTS agent_pending_actions (
        token       TEXT PRIMARY KEY,
        accion      TEXT NOT NULL,      -- 'cancelar_orden'
        orden_id    INTEGER NOT NULL,
        user_id     INTEGER NOT NULL,
        motivo      TEXT,
        usado       INTEGER DEFAULT 0,
        created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.commit()
    conn.close()


def registrar_log(agent_name, user_id, order_id, modelo_usado, mensaje_usuario,
                  tools_llamadas, resultado, costo_estimado_usd, resumen):
    """Nunca debe romper el flujo del agente: cualquier error se traga."""
    try:
        conn = sqlite3.connect(DB)
        c = conn.cursor()
        c.execute("""
            INSERT INTO agent_logs
                (agent_name, user_id, order_id, modelo_usado, mensaje_usuario,
                 tools_llamadas, resultado, costo_estimado_usd, resumen)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (agent_name, user_id, order_id, modelo_usado, mensaje_usuario,
              json.dumps(tools_llamadas), resultado, costo_estimado_usd, resumen))
        conn.commit()
        conn.close()
    except Exception:
        pass


def obtener_logs(limit: int = 100, resultado=None):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    if resultado:
        c.execute("SELECT * FROM agent_logs WHERE resultado = ? ORDER BY id DESC LIMIT ?",
                  (resultado, min(limit, 500)))
    else:
        c.execute("SELECT * FROM agent_logs ORDER BY id DESC LIMIT ?",
                  (min(limit, 500),))
    rows = c.fetchall()
    cols = [d[0] for d in c.description]
    conn.close()
    return [dict(zip(cols, r)) for r in rows]


def resumen_logs():
    """Resumen agregado para 'cómo está funcionando el agente'."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT COUNT(*), COALESCE(SUM(costo_estimado_usd), 0)
        FROM agent_logs
    """)
    total, costo = c.fetchone()
    c.execute("SELECT resultado, COUNT(*) FROM agent_logs GROUP BY resultado")
    por_resultado = dict(c.fetchall())
    c.execute("SELECT modelo_usado, COUNT(*) FROM agent_logs GROUP BY modelo_usado")
    por_modelo = dict(c.fetchall())
    conn.close()
    return {
        "total_interacciones": total,
        "costo_total_usd": round(costo or 0, 4),
        "por_resultado": por_resultado,
        "por_modelo": por_modelo,
        "pct_resuelto_sin_humano": round(
            100.0 * por_resultado.get("resuelto", 0) / total, 1) if total else 0,
    }


# ── Acciones pendientes de confirmación ───────────────────────────────────────

def crear_accion_pendiente(token, accion, orden_id, user_id, motivo=None):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO agent_pending_actions (token, accion, orden_id, user_id, motivo)
        VALUES (?, ?, ?, ?, ?)
    """, (token, accion, orden_id, user_id, motivo))
    conn.commit()
    conn.close()


def obtener_accion_pendiente(token):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT token, accion, orden_id, user_id, motivo, usado, created_at
        FROM agent_pending_actions
        WHERE token = ? AND usado = 0
          AND created_at >= datetime('now', '-30 minutes')
    """, (token,))
    row = c.fetchone()
    conn.close()
    if not row:
        return None
    cols = ["token", "accion", "orden_id", "user_id", "motivo", "usado", "created_at"]
    return dict(zip(cols, row))


def marcar_accion_usada(token):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("UPDATE agent_pending_actions SET usado = 1 WHERE token = ?", (token,))
    conn.commit()
    conn.close()
