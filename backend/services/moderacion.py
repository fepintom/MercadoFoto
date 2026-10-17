"""
services/moderacion.py
======================
Políticas de uso de Comunidad: el bot de OkVenta revisa cada mensaje y
censura al tiro los que traen insultos/groserías, amenazas o hablan de
drogas.

Es por reglas (rápido, sin costo y predecible): el texto se normaliza
(minúsculas, sin tildes, "p.u.t.a" → "puta", "h1j0" → "hijo", letras
repetidas "puuuta" → "puta") y se busca contra listas de palabras y frases
con bordes de palabra, para no pillar palabras inocentes ("computadora",
"disputa", "Coca-Cola").
"""
import re
import unicodedata
from typing import Optional

INSULTOS = [
    "conchetumare", "conchetumadre", "conchatumadre", "conchesumare",
    "concha de tu madre", "concha tu madre", "ctm", "csm", "ctmre",
    "hijo de puta", "hija de puta", "hdp", "hijueputa", "hijo de perra",
    "puta", "puto", "putas", "putos", "putita", "maricon", "maricones",
    "maraco", "maraca", "culiao", "culiado", "culiaos", "culiada",
    "aweonao", "aweonado", "ahueonao", "ahueonado", "saco de wea",
    "saco e wea", "wn culiao", "weon culiao", "tonto culiao",
    "idiota", "imbecil", "imbeciles", "estupido", "estupida", "pendejo",
    "pendeja", "mierda", "mierdas", "cagon", "chupala", "chupalo",
    "la chupai", "pico pal que lee", "andate a la mierda", "vete a la mierda",
    "subnormal", "mongolico", "malparido",
    "gonorrea", "fuck", "fucking", "motherfucker", "bitch", "asshole",
]

AMENAZAS = [
    "te voy a matar", "te mato", "los voy a matar", "lo voy a matar",
    "la voy a matar", "te voy a pegar", "te voy a sacar la cresta",
    "te saco la cresta", "te voy a reventar", "te reviento",
    "te voy a buscar", "voy a ir a tu casa", "se donde vives",
    "se donde vivis", "te voy a encontrar", "vas a morir", "te vas a morir",
    "te voy a quemar", "te quemo la casa", "te pego un tiro",
    "te voy a pegar un tiro", "te meto un balazo", "balazo", "te apunalo",
    "te voy a apunalar", "te voy a cortar", "te voy a funar",
    "te vai a arrepentir", "te vas a arrepentir", "cuidate la espalda",
    "te voy a hacer dano", "te voy a secuestrar", "amenaza de muerte",
]

DROGAS = [
    "marihuana", "mariguana", "marijuana", "cannabis", "cogollo",
    "cogollos", "weed", "porro", "porros", "faso", "hachis",
    "cocaina", "pasta base", "falopa", "tusi", "tussi",
    "tucibi", "extasis", "mdma", "lsd", "keta", "ketamina",
    "metanfetamina", "heroina", "hongos magicos",
    "clonazepam", "rivotril", "ravotril", "tramadol", "fentanilo",
    "vendo droga", "vendo drogas", "compro droga", "compro drogas",
    "venta de drogas", "trafico de drogas", 
]

CATEGORIAS = {
    "insultos": INSULTOS,
    "amenazas": AMENAZAS,
    "drogas": DROGAS,
}

_LEET = str.maketrans({"0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
                       "7": "t", "@": "a", "$": "s", "!": "i"})


def normalizar(texto: str) -> str:
    t = unicodedata.normalize("NFKD", (texto or "").lower())
    t = "".join(c for c in t if not unicodedata.combining(c))
    # Las @menciones no se revisan (un nombre puede parecerse a algo).
    t = re.sub(r"@\w+", " ", t)
    t = t.translate(_LEET)
    t = re.sub(r"[^a-zñ\s.\-_*]", " ", t)
    # "p.u.t.a" / "p-u-t-a" / "p u t a" → "puta"
    t = re.sub(r"\b(?:[a-zñ][\s.\-_*]){2,}[a-zñ]\b",
               lambda m: re.sub(r"[\s.\-_*]", "", m.group(0)), t)
    t = re.sub(r"[.\-_*]", " ", t)
    # "puuuuta" → "puta" (3+ iguales seguidas → 1)
    t = re.sub(r"([a-zñ])\1{2,}", r"\1", t)
    return re.sub(r"\s+", " ", t).strip()


def _patron(lista):
    partes = sorted({re.escape(normalizar(x)) for x in lista}, key=len,
                    reverse=True)
    return re.compile(r"(?<![a-zñ])(?:" + "|".join(partes) + r")(?![a-zñ])")


_PATRONES = {cat: _patron(lista) for cat, lista in CATEGORIAS.items()}


def revisar(texto: str) -> Optional[str]:
    """Devuelve la categoría que incumple ('amenazas', 'insultos',
    'drogas') o None si el mensaje está bien. Las amenazas se revisan
    primero (son lo más grave)."""
    t = normalizar(texto)
    if not t:
        return None
    for cat in ("amenazas", "insultos", "drogas"):
        if _PATRONES[cat].search(t):
            return cat
    return None
