#!/usr/bin/env python3
"""Íconos provisionales de la PWA a partir de public/brand/mp-logo.png (Pillow).

Recorta el símbolo (mano + círculo con el mapa de Panamá, sin la barra ni el texto) y genera:
  public/icons/icon-192.png, icon-512.png          (any: fondo blanco, símbolo al 84 % del ancho)
  public/icons/icon-maskable-192.png, -512.png     (maskable: fondo blanco, símbolo al 62 % para la zona segura)
  public/icons/apple-touch-icon.png                (180 px, fondo blanco)
  public/favicon.ico                               (16, 32 y 48 px)
  ops/caddy/placeholder/mp-logo.png                (logo completo a 600 px de ancho para la página de espera)

PROVISIONAL hasta recibir el SVG oficial del logo MP; entonces se reemplazan por exportaciones del vector.
Uso: python3 scripts/brand/make-icons.py  (desde la raíz del repo)
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "public/brand/mp-logo.png"
OUT = ROOT / "public/icons"
WHITE = (255, 255, 255, 255)
BAR_X = 958  # la barra vertical del logo empieza en x≈961; todo lo anterior es el símbolo


def simbolo() -> Image.Image:
    im = Image.open(SRC).convert("RGBA")
    izquierda = im.crop((0, 0, BAR_X, im.height))
    return izquierda.crop(izquierda.getbbox())


def icono(sym: Image.Image, size: int, escala: float, fondo=WHITE) -> Image.Image:
    lienzo = Image.new("RGBA", (size, size), fondo)
    w = int(size * escala)
    h = int(round(w * sym.height / sym.width))
    if h > w:  # el símbolo es más ancho que alto; por si cambia el recorte
        h = int(size * escala)
        w = int(round(h * sym.width / sym.height))
    pieza = sym.resize((w, h), Image.LANCZOS)
    lienzo.alpha_composite(pieza, ((size - w) // 2, (size - h) // 2))
    return lienzo


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sym = simbolo()
    print(f"símbolo recortado: {sym.size[0]}x{sym.size[1]} px")
    for size in (192, 512):
        icono(sym, size, 0.84).save(OUT / f"icon-{size}.png", optimize=True)
        icono(sym, size, 0.62).save(OUT / f"icon-maskable-{size}.png", optimize=True)
    icono(sym, 180, 0.84).convert("RGB").save(OUT / "apple-touch-icon.png", optimize=True)
    base48 = icono(sym, 48, 0.92).convert("RGB")
    base48.save(ROOT / "public/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    # logo completo reducido para la página de espera (Caddy 503)
    logo = Image.open(SRC).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    w = 600
    h = int(round(w * logo.height / logo.width))
    logo.resize((w, h), Image.LANCZOS).save(ROOT / "ops/caddy/placeholder/mp-logo.png", optimize=True)
    for f in sorted(OUT.iterdir()) + [ROOT / "public/favicon.ico", ROOT / "ops/caddy/placeholder/mp-logo.png"]:
        print(f"{f.relative_to(ROOT)}  {f.stat().st_size} bytes")


if __name__ == "__main__":
    main()
