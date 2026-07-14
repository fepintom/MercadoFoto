"""
Batch image processor — ok-venta-image pipeline
Input:  backend/uploads/*.png
Output: backend/uploads/procesadas/*.jpg
Pipeline: rembg → white bg → bounding box crop → dynamic margin → square canvas
"""
import os
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from rembg import remove


def calcular_margen(lado_mayor: int) -> float:
    if lado_mayor < 300:
        return 0.15
    elif lado_mayor < 800:
        return 0.12
    elif lado_mayor < 1500:
        return 0.10
    else:
        return 0.08


def procesar(input_path: Path, output_path: Path) -> str:
    img = Image.open(input_path).convert("RGBA")

    # Eliminar fondo
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    resultado = remove(buf.getvalue())
    sin_fondo = Image.open(io.BytesIO(resultado)).convert("RGBA")

    # Bounding box del producto (alpha > 10)
    alpha = np.array(sin_fondo)[:, :, 3]
    rows = np.any(alpha > 10, axis=1)
    cols = np.any(alpha > 10, axis=0)

    if not rows.any() or not cols.any():
        return "skip (imagen vacía tras rembg)"

    y1, y2 = int(np.where(rows)[0][0]), int(np.where(rows)[0][-1])
    x1, x2 = int(np.where(cols)[0][0]), int(np.where(cols)[0][-1])

    producto = sin_fondo.crop((x1, y1, x2 + 1, y2 + 1))
    w, h = producto.size

    # Margen dinámico
    lado_mayor = max(w, h)
    pct = calcular_margen(lado_mayor)
    margen = int(lado_mayor * pct)

    # Canvas cuadrado blanco
    lado = lado_mayor + 2 * margen
    canvas = Image.new("RGB", (lado, lado), (255, 255, 255))
    ox = (lado - w) // 2
    oy = (lado - h) // 2
    canvas.paste(producto, (ox, oy), mask=producto.split()[3])

    canvas.save(output_path, format="JPEG", quality=92, optimize=True)
    return f"{lado}×{lado}px, margen {margen}px"


def main():
    uploads = Path(__file__).parent / "uploads"
    salida = uploads / "procesadas"
    salida.mkdir(exist_ok=True)

    archivos = sorted(p for p in uploads.iterdir()
                      if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
                      and p.is_file())

    print(f"Procesando {len(archivos)} imágenes → {salida}")

    ok = err = skip = 0
    for i, archivo in enumerate(archivos, 1):
        dest = salida / (archivo.stem + ".jpg")
        try:
            info = procesar(archivo, dest)
            if info.startswith("skip"):
                print(f"  [{i}/{len(archivos)}] SKIP  {archivo.name} — {info}")
                skip += 1
            else:
                print(f"  [{i}/{len(archivos)}] OK    {archivo.name} → {info}")
                ok += 1
        except Exception as e:
            print(f"  [{i}/{len(archivos)}] ERROR {archivo.name}: {e}", file=sys.stderr)
            err += 1

    print(f"\nResultado: {ok} OK · {skip} skip · {err} errores")


if __name__ == "__main__":
    main()
