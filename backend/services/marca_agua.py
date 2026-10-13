"""
services/marca_agua.py
======================
Foto de publicación con el estilo OkVenta:

  1. el producto ya sin fondo (rembg) se recorta a su contorno,
  2. se centra en un lienzo cuadrado gris claro de estudio (degradado suave
     + sombra elíptica bajo el producto),
  3. el sello de agua "OK Venta App" (texto diagonal repetido, tenue) va en
     el FONDO, detrás del producto: nada tapa el producto.

Así todas las fotos se ven parejas y no se pueden reutilizar en otra
plataforma sin que se note de dónde salieron.
"""
import io
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

_FUENTES = Path(__file__).resolve().parent.parent / "assets" / "fonts"
LADO = 1000                      # px del lienzo final
GRIS_ARRIBA = (240, 240, 243)    # degradado del fondo (arriba → abajo)
GRIS_ABAJO = (222, 222, 227)
TEXTO_MARCA = "OK Venta App"


def _fuente(tam: int, negrita: bool = True):
    nombre = "DejaVuSans-Bold.ttf" if negrita else "DejaVuSans.ttf"
    try:
        return ImageFont.truetype(str(_FUENTES / nombre), tam)
    except Exception:
        try:
            return ImageFont.load_default(size=tam)
        except Exception:
            return ImageFont.load_default()


def _fondo(lado: int) -> Image.Image:
    col = Image.new("RGB", (1, lado))
    for y in range(lado):
        t = y / max(1, lado - 1)
        col.putpixel((0, y), tuple(
            int(GRIS_ARRIBA[i] + (GRIS_ABAJO[i] - GRIS_ARRIBA[i]) * t)
            for i in range(3)))
    return col.resize((lado, lado)).convert("RGBA")


def _texto_diagonal(lado: int) -> Image.Image:
    """Capa con "OK Venta App" repetido en diagonal, muy tenue."""
    grande = int(lado * 1.6)
    capa = Image.new("RGBA", (grande, grande), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    f = _fuente(max(14, lado // 26))
    paso_x = lado // 3
    paso_y = lado // 5
    for fila, y in enumerate(range(0, grande, paso_y)):
        desfase = (paso_x // 2) * (fila % 2)
        for x in range(-paso_x, grande, paso_x):
            d.text((x + desfase, y), TEXTO_MARCA, font=f,
                   fill=(150, 150, 158, 52))
    capa = capa.rotate(28, resample=Image.BICUBIC)
    o = (grande - lado) // 2
    return capa.crop((o, o, o + lado, o + lado))


def _logo_central(lado: int) -> Image.Image:
    """"✓ OK Venta" grande + "APP" espaciado, blanco semitransparente."""
    capa = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    f = _fuente(lado // 9)
    f2 = _fuente(lado // 28, negrita=False)
    texto = "OK Venta"
    bb = d.textbbox((0, 0), texto, font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    chk = int(th * 0.95)                       # ancho del ✓
    total = chk + int(lado * 0.02) + tw
    x0 = (lado - total) // 2
    y0 = (lado - th) // 2 - lado // 40
    blanco = (255, 255, 255, 150)
    # ✓ dibujado con líneas (no depende de que la fuente tenga el glifo)
    grosor = max(4, lado // 70)
    d.line([(x0, y0 + th * 0.55), (x0 + chk * 0.38, y0 + th * 0.92),
            (x0 + chk, y0 + th * 0.05)], fill=blanco, width=grosor,
           joint="curve")
    d.text((x0 + chk + int(lado * 0.02) - bb[0], y0 - bb[1]), texto,
           font=f, fill=blanco)
    app = "A P P"
    bb2 = d.textbbox((0, 0), app, font=f2)
    d.text(((lado - (bb2[2] - bb2[0])) // 2 + chk // 2,
            y0 + th + lado // 60 - bb2[1]), app, font=f2, fill=blanco)
    # Un borde gris muy suave para que se lea también sobre productos claros.
    sombra = capa.filter(ImageFilter.GaussianBlur(2))
    gris = Image.new("RGBA", capa.size, (90, 90, 100, 0))
    gris.putalpha(sombra.getchannel("A").point(lambda a: int(a * 0.35)))
    return Image.alpha_composite(gris, capa)


def componer(producto_rgba: Image.Image, lado: int = LADO) -> Image.Image:
    """Producto sin fondo → foto final OkVenta (RGB)."""
    img = producto_rgba.convert("RGBA")
    caja = img.getchannel("A").point(lambda a: 255 if a > 12 else 0).getbbox()
    if caja:
        img = img.crop(caja)
    w, h = img.size
    # El producto ocupa ~86 % del lado mayor: grande y centrado, con un
    # poco de aire alrededor (como estudio).
    escala = (lado * 0.86) / max(w, h, 1)
    img = img.resize((max(1, int(w * escala)), max(1, int(h * escala))),
                     Image.LANCZOS)
    w, h = img.size

    # Fondo gris + sello de agua (detrás del producto).
    lienzo = Image.alpha_composite(_fondo(lado), _texto_diagonal(lado))
    x = (lado - w) // 2
    y = (lado - h) // 2

    # Sombra suave bajo el producto.
    sombra = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sombra)
    ancho_s = int(w * 0.8)
    alto_s = max(8, int(lado * 0.035))
    base = y + h - alto_s // 3
    ds.ellipse([(lado - ancho_s) // 2, base, (lado + ancho_s) // 2,
                base + alto_s], fill=(0, 0, 0, 55))
    sombra = sombra.filter(ImageFilter.GaussianBlur(lado // 60))
    lienzo = Image.alpha_composite(lienzo, sombra)

    lienzo.alpha_composite(img, (x, y))
    return lienzo.convert("RGB")


def componer_jpeg(producto_rgba: Image.Image, calidad: int = 82) -> bytes:
    buf = io.BytesIO()
    componer(producto_rgba).save(buf, format="JPEG", quality=calidad,
                                 optimize=True)
    return buf.getvalue()
