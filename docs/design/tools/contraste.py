#!/usr/bin/env python3
"""Auditoría de contraste WCAG 2.1 AA de los tokens MP (styles/tokens.css) en las combinaciones que usan las pantallas.

Imprime una tabla Markdown para docs/design/README.md. Umbrales: texto normal 4.5:1, texto grande (≥ 24 px o ≥ 19 px negrita) 3:1,
componentes y gráficos 3:1 (1.4.11). Sale con código 1 si alguna combinación falla.
Uso: python3 docs/design/tools/contraste.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOKENS = ROOT / "styles/tokens.css"


def leer_tokens() -> dict:
    t = {}
    for m in re.finditer(r"(--[\w-]+):\s*(#[0-9A-Fa-f]{6})", TOKENS.read_text()):
        t[m.group(1)] = m.group(2).upper()
    for m in re.finditer(r"(--estado-[\w-]+):\s*var\((--[\w-]+)\)", TOKENS.read_text()):
        t[m.group(1)] = t[m.group(2)]
    return t


def lum(h: str) -> float:
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def ratio(a: str, b: str) -> float:
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def mezcla(fg: str, bg: str, alpha: float) -> str:
    f = [int(fg[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(bg[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02X%02X%02X" % tuple(round(alpha * x + (1 - alpha) * y) for x, y in zip(f, b))


def main() -> int:
    t = leer_tokens()
    W, G1, AZ = t["--mp-blanco"], t["--mp-gris-100"], t["--mp-azul"]
    # (elemento, primer plano, fondo, mínimo)
    casos = [
        ("Texto principal sobre blanco (tarjetas)", t["--mp-texto"], W, 4.5),
        ("Texto principal sobre gris-100 (página)", t["--mp-texto"], G1, 4.5),
        ("Texto secundario 14 px sobre blanco", t["--mp-gris-600"], W, 4.5),
        ("Texto secundario 14 px sobre gris-100", t["--mp-gris-600"], G1, 4.5),
        ("Texto secundario sobre azul-50 (fila seleccionada)", t["--mp-gris-600"], t["--mp-azul-50"], 4.5),
        ("Enlaces y botón secundario (azul sobre blanco)", AZ, W, 4.5),
        ("Blanco sobre azul (banda, botón, bloque de cifra)", W, AZ, 4.5),
        ("Blanco al 85 % sobre azul (etiquetas del bloque)", mezcla(W, AZ, 0.85), AZ, 4.5),
        ("Borde del chip 'Datos de ejemplo' (blanco 55 %) sobre azul", mezcla(W, AZ, 0.55), AZ, 3.0),
        ("Blanco sobre azul-900 (pressed)", W, t["--mp-azul-900"], 4.5),
        ("Acento como texto sobre blanco", t["--mp-acento"], W, 4.5),
        ("Acento-700 como texto sobre gris-100", t["--mp-acento-700"], G1, 4.5),
        ("Alerta (texto 'vence') sobre blanco", t["--mp-alerta"], W, 4.5),
        ("Error (texto 'vencido', cifra) sobre blanco", t["--mp-error"], W, 4.5),
        ("Éxito (punto de insignia) sobre blanco", t["--mp-exito"], W, 3.0),
        ("Anillo de foco (acento) sobre gris-100", t["--mp-acento"], G1, 3.0),
        ("Anillo de foco (acento) sobre blanco", t["--mp-acento"], W, 3.0),
        ("Anillo de foco en la banda (acento-claro sobre azul)", t["--mp-acento-claro"], AZ, 3.0),
        ("Segmento actual del avance (acento sobre gris-100)", t["--mp-acento"], G1, 3.0),
        ("Segmentos hechos del avance (azul sobre gris-100)", AZ, G1, 3.0),
        ("Bordes de inputs, chips y radios (gris-400 sobre blanco)", t["--mp-gris-400"], W, 3.0),
        ("Punto de insignia 'en proceso' (azul sobre blanco)", AZ, W, 3.0),
        ("Punto de insignia 'Due Today' (acento sobre blanco)", t["--estado-due-today"], W, 3.0),
        ("Punto de la línea de tiempo hecho (azul sobre gris-100)", AZ, G1, 3.0),
        ("Radio elegido: borde azul sobre blanco", AZ, W, 3.0),
    ]
    filas = []
    fallos = 0
    for nombre, fg, bg, minimo in casos:
        r = ratio(fg, bg)
        ok = r >= minimo
        fallos += 0 if ok else 1
        filas.append(f"| {nombre} | `{fg}` | `{bg}` | {r:.2f}:1 | {minimo:.1f}:1 | {'Pasa' if ok else 'FALLA'} |")
    print("| Elemento | Primer plano | Fondo | Medido | Mínimo | Resultado |")
    print("|---|---|---|---|---|---|")
    print("\n".join(filas))
    print(f"\n{len(casos)} combinaciones, {fallos} fallos.")
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
