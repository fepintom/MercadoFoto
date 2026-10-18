"""
services/okventin_servicio.py
=============================
Okventín "de oficio" para cada aviso de OkServicios.

Una figura genérica de Okventín (assets/okventin/base.png) a la que se le
agregan accesorios según el tipo de servicio:

  - lo que tiene en la mano levantada (martillo, llave inglesa, rodillo...),
  - algo en el suelo, a su lado (huincha, tarro de pintura, neumático...),
  - algo en la cabeza (casco, gorro de chef, sombrero de paja...).

Los accesorios son PNG sueltos en assets/okventin/items/<nombre>.png: si un
diseñador hace versiones nuevas, se reemplazan los archivos y listo (se
sube VERSION para que la app no muestre la imagen vieja de caché).

El "kit" (qué oficio es) se elige por palabras del título/descripción y, si
no calza ninguna, por la categoría. Las imágenes se arman una sola vez por
kit y quedan guardadas en UPLOADS_DIR/okventin/.
"""
import io
import os
import re
import threading
import unicodedata

from PIL import Image

_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "assets", "okventin")
_ITEMS = os.path.join(_DIR, "items")

VERSION = 3

# Puntos de la figura base (en píxeles de base.png, 1254 × 1254).
_PUNO = (276, 512)        # centro del puño levantado (mano derecha)
_ZONA_PUNO = (150, 340, 420, 660)  # recuadro del guante levantado
_CABEZA_Y = 262           # borde superior de la bolsa (donde apoya un gorro)
_CABEZA_X = 640
_OJOS = (668, 455)        # centro entre los ojos (para lentes)
_PISO_Y = 1228            # suela de las zapatillas

# Cómo se toma cada herramienta: (punto de agarre en fracción del ancho/alto
# de la imagen, lado mayor en px, giro en grados).
_AGARRE = {
    "martillo": ((0.70, 0.78), 400, 0),
    "llave_inglesa": ((0.62, 0.80), 400, 0),
    "alicate": ((0.55, 0.82), 380, 0),
    "rodillo": ((0.68, 0.82), 400, 0),
    "tijera_podar": ((0.58, 0.82), 380, 0),
    "serrucho": ((0.80, 0.84), 470, 0),
    "llave": ((0.55, 0.80), 300, 0),
    "llave_cruz": ((0.85, 0.85), 380, 0),
    "volante": ((0.14, 0.55), 330, 0),
    "destornillador": ((0.32, 0.92), 420, 0),
    "huincha": ((0.30, 0.50), 300, 0),
    "estetoscopio": ((0.30, 0.15), 380, 0),
    "tijera_peine": ((0.45, 0.78), 380, 0),
    "lapiz": ((0.45, 0.80), 330, 0),
    "camara": ((0.40, 0.65), 320, 0),
    "correa": ((0.50, 0.03), 440, 0),
    "cuchara": ((0.50, 0.82), 360, 0),
    "escoba": ((0.55, 0.30), 520, 0),
    "herramientas": ((0.50, 0.62), 380, 0),
    "portapapeles": ((0.50, 0.75), 330, 0),
    "celular": ((0.50, 0.70), 280, 0),
    "mouse": ((0.85, 0.95), 230, 0),
    "ampolleta": ((0.50, 0.88), 260, 0),
}

# Alto (px) de lo que va en el suelo y ancho de lo que va en la cabeza.
_ALTO_PISO = {"lavadora": 380, "refrigerador": 470, "neumatico": 300,
              "caja": 280, "bolsa_caja": 320, "tabla": 340, "balde": 260,
              "planta": 300, "tarro_pintura": 260, "olla": 220,
              "botiquin": 230, "libros": 210, "maletin": 260, "hueso": 160,
              "candado": 230, "tubo": 210, "huincha": 190, "notebook": 260,
              "ampolleta": 220}
_ANCHO_CABEZA = {"casco": 470, "casco_electrico": 470, "gorra": 440,
                 "jockey": 440, "gorro_papel": 400, "sombrero_paja": 560,
                 "gorro_chef": 380, "audifonos": 560, "lentes": 400}

# Cada oficio: (cabeza, mano, suelo). None = nada.
KITS = {
    "construccion": ("casco", "martillo", "huincha"),
    "gasfiteria": ("gorra", "llave_inglesa", "tubo"),
    "electricidad": ("casco_electrico", "alicate", "ampolleta"),
    "pintura": ("gorro_papel", "rodillo", "tarro_pintura"),
    "jardineria": ("sombrero_paja", "tijera_podar", "planta"),
    "carpinteria": ("casco", "serrucho", "tabla"),
    "cerrajeria": (None, "llave", "candado"),
    "mecanica": ("gorra", "llave_cruz", "neumatico"),
    "transporte": ("jockey", "volante", "caja"),
    "mudanza": ("jockey", "volante", "bolsa_caja"),
    "electrodomesticos": ("gorra", "destornillador", "lavadora"),
    "refrigeracion": ("gorra", "destornillador", "refrigerador"),
    "limpieza": (None, "escoba", "balde"),
    "computacion": ("audifonos", "mouse", "notebook"),
    "celulares": ("lentes", "destornillador", None),
    "salud": (None, "estetoscopio", "botiquin"),
    "belleza": (None, "tijera_peine", None),
    "clases": ("lentes", "lapiz", "libros"),
    "profesional": ("lentes", "portapapeles", "maletin"),
    "fotografia": (None, "camara", None),
    "mascotas": (None, "correa", "hueso"),
    "cocina": ("gorro_chef", "cuchara", "olla"),
    "delivery": ("jockey", "celular", "bolsa_caja"),
    "otros": (None, "herramientas", None),
}

# Palabras del título/descripción → oficio (se revisa en este orden).
_PALABRAS = [
    ("mascotas", r"mascot|perro|gato|veterin|paseador|peluqueria canina"),
    ("gasfiteria", r"gasfit|plomer|cañer|caner|fuga|calefon|desagu|sanitari|grifer|llave de agua"),
    ("electricidad", r"electric|enchufe|tablero|cableado|luminaria|instalacion electrica|automatico"),
    ("pintura", r"pint|barniz|empapel|estuco"),
    ("jardineria", r"jardin|poda|pasto|cesped|riego|paisaj|arbol"),
    ("carpinteria", r"carpint|mueble|madera|melamina|closet|mueblista"),
    ("cerrajeria", r"cerraj|chapa|candado|llaves?\b"),
    ("mecanica", r"mecanic|auto|vehicul|neumatic|frenos|motor|scanner automotriz|vulcaniz"),
    ("mudanza", r"mudanz|flete"),
    ("transporte", r"transport|chofer|conductor|traslado|taxi|uber|camion"),
    ("refrigeracion", r"refriger|aire acondicionado|climatiz|split"),
    ("electrodomesticos", r"electrodomest|lavadora|secadora|lavavajilla|microondas|horno|cocina a gas|calefont"),
    ("limpieza", r"limpi|\baseo\b|lavado de|alfombra|tapiz|sanitiz"),
    ("celulares", r"celular|telefono|pantalla|iphone|android"),
    ("computacion", r"comput|notebook|pc\b|software|programa|pagina web|redes|soporte ti|informatic|diseno web"),
    ("salud", r"salud|enferm|kinesi|medic|terapia|masaj|nutri|psicolog|cuidado de adulto|podolog"),
    ("belleza", r"pelu|corte de pelo|barber|manicur|unas|maquill|estetic|depila|cejas|pestanas"),
    ("clases", r"clase|profesor|tutor|reforzamiento|idioma|ingles|matematica|musica|curso"),
    ("fotografia", r"foto|video|filmac|evento"),
    ("cocina", r"cocin|chef|banquet|catering|reposter|torta|comida|pasteler"),
    ("delivery", r"delivery|encargo|despacho|compras por ti|mandado"),
    ("profesional", r"abogad|contad|asesor|consult|tramite|arquitect|ingenier|notari"),
    ("construccion", r"constru|maestro|albañil|albanil|ceramic|remodel|obra|techo|radier|soldad|tabique|gasfiter"),
]

_POR_CATEGORIA = {
    "construccion": "construccion", "transporte": "transporte",
    "electrodomesticos": "electrodomesticos", "salud": "salud",
    "profesional": "profesional", "asesorias": "profesional",
    "computacion": "computacion", "servicio": "otros", "otros": "otros",
}


def _norm(t):
    t = unicodedata.normalize("NFKD", (t or "").lower())
    return "".join(c for c in t if not unicodedata.combining(c))


def elegir_kit(titulo="", categoria="", descripcion="") -> str:
    """Qué Okventín le toca a un servicio."""
    texto = _norm(f"{titulo} {descripcion}")
    tit = _norm(titulo)
    # Primero solo el título (es lo más claro), después con la descripción.
    for fuente in (tit, texto):
        for kit, patron in _PALABRAS:
            if re.search(patron, fuente):
                return kit
    return _POR_CATEGORIA.get(_norm(categoria), "otros")


# ── Composición ────────────────────────────────────────────────────────────

_cache_items = {}


def _item(nombre):
    if nombre not in _cache_items:
        _cache_items[nombre] = Image.open(
            os.path.join(_ITEMS, f"{nombre}.png")).convert("RGBA")
    return _cache_items[nombre]


def _escalar(im, lado=None, alto=None, ancho=None):
    w, h = im.size
    if lado:
        f = lado / max(w, h)
    elif alto:
        f = alto / h
    else:
        f = ancho / w
    return im.resize((max(1, int(w * f)), max(1, int(h * f))), Image.LANCZOS)


_cache_guante = {}


def _guante(base):
    """Solo el guante blanco del puño levantado (recortado de la base)."""
    if "g" not in _cache_guante:
        zona = base.crop(_ZONA_PUNO)
        px = zona.load()
        mascara = Image.new("L", zona.size, 0)
        mk = mascara.load()
        for y in range(zona.height):
            for x in range(zona.width):
                r, g, b, a = px[x, y]
                if a > 0 and min(r, g, b) > 135 and max(r, g, b) - min(r, g, b) < 45:
                    mk[x, y] = a
        from PIL import ImageFilter
        mascara = mascara.filter(ImageFilter.MaxFilter(3)).filter(
            ImageFilter.GaussianBlur(0.8))
        g = zona.copy()
        g.putalpha(mascara)
        _cache_guante["g"] = g
    return _cache_guante["g"]


# Figuras terminadas, una por oficio (assets/okventin/oficios/<kit>.png).
# Si existe, se usa tal cual; si no, se arma con la base + accesorios.
_OFICIOS = os.path.join(_DIR, "oficios")
# Oficios sin figura propia → el más parecido que sí tiene.
_PARECIDO = {"mudanza": "transporte", "delivery": "transporte",
             "refrigeracion": "electrodomesticos", "celulares": "computacion"}


def figura(kit: str) -> Image.Image:
    """La figura de Okventín para el oficio (RGBA, fondo transparente)."""
    for k in (kit, _PARECIDO.get(kit)):
        if k:
            ruta = os.path.join(_OFICIOS, f"{k}.png")
            if os.path.isfile(ruta):
                return Image.open(ruta).convert("RGBA")
    return componer_kit(kit)


def con_sombra(fig: Image.Image, dx=10, dy=16, blur=14, opacidad=0.35):
    """La figura con una sombra difuminada suave detrás (más realista)."""
    from PIL import ImageFilter
    pad = blur * 3 + max(dx, dy)
    w, h = fig.size
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    sombra = Image.new("RGBA", fig.size, (0, 0, 0, 255))
    sombra.putalpha(fig.getchannel("A").point(lambda v: int(v * opacidad)))
    out.alpha_composite(sombra, (pad + dx, pad + dy))
    out = out.filter(ImageFilter.GaussianBlur(blur))
    out.alpha_composite(fig, (pad, pad))
    return out.crop(out.getbbox())


def componer_kit(kit: str) -> Image.Image:
    """Okventín con los accesorios del kit (RGBA, fondo transparente)."""
    cabeza, mano, piso = KITS.get(kit, KITS["otros"])
    base = Image.open(os.path.join(_DIR, "base.png")).convert("RGBA")
    # Lienzo con aire para la herramienta levantada (arriba/izquierda) y
    # para lo que va en el suelo (derecha).
    margen_izq, margen_arr, margen_der = 300, 260, 380
    W = base.width + margen_izq + margen_der
    H = base.height + margen_arr
    lienzo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ox, oy = margen_izq, margen_arr

    lienzo.alpha_composite(base, (ox, oy))

    # 1) Herramienta en la mano: va delante del cuerpo y después se vuelve
    #    a pintar el guante encima, así el puño "agarra" el mango.
    if mano:
        (gx, gy), lado, giro = _AGARRE.get(mano, ((0.5, 0.75), 360, 0))
        h = _escalar(_item(mano), lado=int(lado * 1.2))
        if giro:
            h = h.rotate(giro, expand=True, resample=Image.BICUBIC)
        px = ox + _PUNO[0] - int(h.width * gx)
        py = oy + _PUNO[1] - int(h.height * gy)
        lienzo.alpha_composite(h, (max(0, px), max(0, py)))
        lienzo.alpha_composite(_guante(base), (ox + _ZONA_PUNO[0],
                                               oy + _ZONA_PUNO[1]))

    # 2) Lo de la cabeza (o los lentes en los ojos), encima.
    if cabeza:
        c = _escalar(_item(cabeza), ancho=_ANCHO_CABEZA.get(cabeza, 440))
        if cabeza == "lentes":
            cx, cy = ox + _OJOS[0] - c.width // 2, oy + _OJOS[1] - c.height // 2
        elif cabeza == "audifonos":
            cx = ox + _CABEZA_X - c.width // 2
            cy = oy + _CABEZA_Y - int(c.height * 0.45)
        else:
            cx = ox + _CABEZA_X - c.width // 2
            # el gorro "calza": su borde inferior un poco bajo el borde de
            # la bolsa
            cy = oy + _CABEZA_Y - int(c.height * 0.80)
        lienzo.alpha_composite(c, (max(0, cx), max(0, cy)))

    # 3) Lo del suelo, a su lado derecho (delante, junto a la zapatilla).
    if piso:
        s = _escalar(_item(piso), alto=int(_ALTO_PISO.get(piso, 260) * 1.45))
        sx = ox + base.width - 250
        if sx + s.width > W:
            sx = W - s.width
        sy = oy + _PISO_Y - s.height
        lienzo.alpha_composite(s, (sx, sy))

    caja = lienzo.getbbox()
    return lienzo.crop(caja) if caja else lienzo


# ── Sello: Okventín dentro del marco redondo ───────────────────────────────

FONDO_SELLO = (242, 242, 247, 255)   # el gris claro de la app (#F2F2F7)
_cache_hueco = {}


def _hueco(marco):
    """Máscara del interior del marco (lo transparente conectado al centro)."""
    if "h" not in _cache_hueco:
        from PIL import ImageDraw
        a = marco.getchannel("A").point(lambda v: 255 if v < 60 else 0)
        cx, cy = marco.width // 2, int(marco.height * 0.48)
        relleno = a.copy()
        ImageDraw.floodfill(relleno, (cx, cy), 128)
        _cache_hueco["h"] = relleno.point(lambda v: 255 if v == 128 else 0)
    return _cache_hueco["h"]


def componer_sello(kit: str) -> Image.Image:
    """Okventín de oficio dentro del marco rojo con estrellas, sobre el gris
    claro de la app, con una sombra suave alrededor (RGBA)."""
    from PIL import ImageChops, ImageFilter
    marco = Image.open(os.path.join(_DIR, "marco.png")).convert("RGBA")
    hueco = _hueco(marco)
    W, H = marco.size
    capa = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # 1) fondo claro (un poco más grande que el hueco: queda bajo el aro)
    fondo = Image.new("RGBA", (W, H), FONDO_SELLO)
    capa.paste(fondo, (0, 0), hueco.filter(ImageFilter.MaxFilter(25)))
    # 2) Okventín, recortado al hueco
    caja = hueco.getbbox()
    fig = figura(kit)
    fig = _escalar(fig, alto=int((caja[3] - caja[1]) * 0.92))
    fig = con_sombra(fig, dx=12, dy=18, blur=16, opacidad=0.32)
    if fig.width > (caja[2] - caja[0]) * 0.92:
        fig = _escalar(fig, ancho=int((caja[2] - caja[0]) * 0.92))
    fx = (caja[0] + caja[2]) // 2 - fig.width // 2
    fy = caja[3] - fig.height - int((caja[3] - caja[1]) * 0.02)
    tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tmp.alpha_composite(fig, (fx, fy))
    tmp.putalpha(ImageChops.multiply(tmp.getchannel("A"),
                                     hueco.filter(ImageFilter.MaxFilter(9))))
    capa.alpha_composite(tmp)
    # 3) el marco encima
    capa.alpha_composite(marco)
    # 4) sombra difuminada leve (abajo, como si flotara)
    pad = 60
    total = Image.new("RGBA", (W + pad * 2, H + pad * 2), (0, 0, 0, 0))
    sombra = Image.new("RGBA", capa.size, (0, 0, 0, 255))
    sombra.putalpha(capa.getchannel("A").point(lambda v: int(v * 0.30)))
    total.alpha_composite(sombra, (pad, pad + 18))
    total = total.filter(ImageFilter.GaussianBlur(18))
    total.alpha_composite(capa, (pad, pad))
    return total


# ── Archivos listos (caché en disco) ───────────────────────────────────────

_lock = threading.Lock()


def _carpeta():
    from config import UPLOADS_DIR
    d = os.path.join(UPLOADS_DIR, "okventin")
    os.makedirs(d, exist_ok=True)
    return d


def ruta_imagen(kit: str, formato: str = "png") -> str:
    """Devuelve la ruta del archivo (lo arma si no existe).
    formato 'png' = transparente (sello); 'jpg' = foto de estudio."""
    if kit not in KITS:
        kit = "otros"
    formato = "jpg" if formato == "jpg" else "png"
    ruta = os.path.join(_carpeta(), f"{kit}_v{VERSION}.{formato}")
    if os.path.isfile(ruta):
        return ruta
    with _lock:
        if os.path.isfile(ruta):
            return ruta
        if formato == "png":
            fig = componer_sello(kit)
            fig.thumbnail((360, 360), Image.LANCZOS)
            fig.save(ruta, format="PNG", optimize=True)
        else:
            # Foto de estudio: fondo claro con sello de agua, Okventín con
            # su sombra. A 720 px (la figura original es chica).
            fig = con_sombra(figura(kit), dx=8, dy=12, blur=10, opacidad=0.30)
            from services.marca_agua import componer
            componer(fig, lado=720).save(ruta, format="JPEG", quality=88,
                                          optimize=True)
    return ruta


def url(kit: str, formato: str = "jpg") -> str:
    return f"/okventin/servicio/{kit}.{formato}?v={VERSION}"


def generar_todos():
    for k in KITS:
        for f in ("png", "jpg"):
            try:
                ruta_imagen(k, f)
            except Exception as e:  # una figura mala no corta el resto
                print("okventin_servicio:", k, f, repr(e))
