#!/usr/bin/env python3
"""Construye la página única del Artifact privado (revisión en celular) a partir de las 5 pantallas clave.

Entrada: styles/tokens.css, docs/design/pantallas/base.css y 01…05_*.html.
Salida: la ruta que se pase como argumento (por defecto docs/design/tools/out/artifact.html); los logos se publican aparte
(mp-logo.png y logo.png reducidos). La página mantiene un solo tema (marca MP) por decisión del contrato de diseño.
Uso: python3 docs/design/tools/build_artifact.py [salida.html]
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
P = ROOT / "docs/design/pantallas"
PANTALLAS = [
    ("01_wizard_monto.html", "Wizard de monto"),
    ("02_timeline_solicitud.html", "Línea de tiempo"),
    ("03_estado_cuenta.html", "Estado de cuenta"),
    ("04_base_diaria_carga.html", "Base Diaria"),
    ("05_admin_bandeja.html", "Bandeja admin"),
]

EXTRA_CSS = """
/* Diseño de un solo tema (marca MP) por decisión: fondos y colores explícitos. */
:root{color-scheme:light}
body{background:var(--mp-gris-100);color:var(--mp-texto)}
.selector{position:sticky;top:env(safe-area-inset-top,0px);z-index:5;background:var(--mp-blanco);border-bottom:1px solid var(--mp-gris-200);padding:8px 16px;display:flex;gap:6px;overflow-x:auto;white-space:nowrap}
.selector button{min-height:40px;padding:0 12px;border-radius:999px;border:1px solid var(--mp-gris-400);background:var(--mp-blanco);color:var(--mp-texto);font:inherit;font-size:var(--mp-text-sm);font-weight:600;cursor:pointer;flex:none}
.selector button[aria-pressed="true"]{background:var(--mp-azul);border-color:var(--mp-azul);color:var(--mp-blanco)}
.selector .nota{align-self:center;color:var(--mp-gris-600);font-size:var(--mp-text-xs);flex:none}
.pie{padding-bottom:calc(12px + env(safe-area-inset-bottom,0px))}
"""

SCRIPT = """
<script>
(function(){
  var btns=Array.prototype.slice.call(document.querySelectorAll('.selector button'));
  var secs=Array.prototype.slice.call(document.querySelectorAll('.pantalla'));
  function show(i){
    secs.forEach(function(s,j){s.hidden=j!==i});
    btns.forEach(function(b,j){b.setAttribute('aria-pressed',String(j===i))});
    window.scrollTo(0,0);
    try{history.replaceState(null,'','#p'+(i+1))}catch(e){}
  }
  btns.forEach(function(b,i){b.addEventListener('click',function(){show(i)})});
  var m=/^#p([1-5])$/.exec(location.hash); if(m){show(+m[1]-1)}
})();
</script>
"""


def cuerpo(html: str) -> str:
    """Todo lo que hay entre <body> y </body>, con las rutas de los logos aplanadas."""
    m = re.search(r"<body>\s*(.*?)\s*</body>", html, re.S)
    if not m:
        raise SystemExit("sin <body>")
    s = m.group(1)
    s = s.replace("../../../public/brand/mp-logo.png", "mp-logo.png")
    s = s.replace("../../../public/brand/logo.png", "logo.png")
    return s


def main() -> None:
    salida = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/design/tools/out/artifact.html"
    salida.parent.mkdir(parents=True, exist_ok=True)
    tokens = (ROOT / "styles/tokens.css").read_text()
    base = (P / "base.css").read_text()
    partes = [
        "<title>Pantallas MP</title>",
        '<link rel="preconnect" href="https://fonts.googleapis.com">',
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
        '<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;600;700&display=swap" rel="stylesheet">',
        "<style>",
        "/* Tokens MP: la fuente de verdad es styles/tokens.css del repo mp-app; aquí van copiados para el Artifact. */",
        tokens,
        base,
        EXTRA_CSS,
        "</style>",
    ]
    sel = ['<div class="selector" role="group" aria-label="Elegir pantalla">']
    for i, (_, titulo) in enumerate(PANTALLAS, 1):
        sel.append(f'<button type="button" id="b{i}" aria-pressed="{str(i == 1).lower()}" aria-controls="p{i}">{i}. {titulo}</button>')
    sel.append('<span class="nota">Datos ficticios</span></div>')
    partes.append("".join(sel))
    for i, (archivo, titulo) in enumerate(PANTALLAS, 1):
        hidden = "" if i == 1 else " hidden"
        partes.append(f'<section class="pantalla" id="p{i}" aria-label="{titulo}"{hidden}>')
        partes.append(cuerpo((P / archivo).read_text()))
        partes.append("</section>")
    partes.append(SCRIPT)
    salida.write_text("\n".join(partes))
    print(f"{salida} ({salida.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
