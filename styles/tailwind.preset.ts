import type { Config } from "tailwindcss";

/**
 * Preset de marca FIC. Fuente única de valores: styles/tokens.css.
 * Brief 02: en tailwind.config.ts usar `presets: [ficPreset]` e importar styles/tokens.css en app/globals.css.
 * Nota: al referenciar variables CSS, los modificadores de opacidad de Tailwind (bg-fic-azul/50) no aplican;
 * si el Brief 02 los necesita, exponer canales RGB en tokens.css y usar `rgb(var(--x) / <alpha-value>)`.
 */
const ficPreset: Partial<Config> = {
  theme: {
    // Regla §15: una sola sombra. Se define fuera de extend para retirar shadow-md/lg/xl/2xl de Tailwind.
    boxShadow: { none: "none", sm: "var(--fic-shadow-sm)" },
    extend: {
      colors: {
        fic: {
          azul: "var(--fic-azul)",
          "azul-claro": "var(--fic-azul-claro)",
          "azul-900": "var(--fic-azul-900)",
          blanco: "var(--fic-blanco)",
          "gris-100": "var(--fic-gris-100)",
          "gris-200": "var(--fic-gris-200)",
          "gris-300": "var(--fic-gris-300)",
          "gris-400": "var(--fic-gris-400)",
          "gris-600": "var(--fic-gris-600)",
          texto: "var(--fic-texto)",
          exito: "var(--fic-exito)",
          alerta: "var(--fic-alerta)",
          error: "var(--fic-error)",
        },
        estado: {
          current: "var(--estado-current)",
          "due-today": "var(--estado-due-today)",
          missed: "var(--estado-missed)",
          arrears: "var(--estado-arrears)",
          "past-maturity": "var(--estado-past-maturity)",
        },
      },
      fontFamily: {
        sans: ["var(--fic-font-sans)"],
        mono: ["var(--fic-font-mono)"],
      },
      fontSize: {
        xs: ["var(--fic-text-xs)", { lineHeight: "var(--fic-leading-normal)" }],
        sm: ["var(--fic-text-sm)", { lineHeight: "var(--fic-leading-normal)" }],
        base: ["var(--fic-text-base)", { lineHeight: "var(--fic-leading-normal)" }],
        lg: ["var(--fic-text-lg)", { lineHeight: "var(--fic-leading-normal)" }],
        xl: ["var(--fic-text-xl)", { lineHeight: "var(--fic-leading-tight)" }],
        "2xl": ["var(--fic-text-2xl)", { lineHeight: "var(--fic-leading-tight)" }],
        "3xl": ["var(--fic-text-3xl)", { lineHeight: "var(--fic-leading-tight)" }],
      },
      borderRadius: {
        sm: "var(--fic-radius-sm)",
        md: "var(--fic-radius-md)",
        lg: "var(--fic-radius-lg)",
      },
      minHeight: { touch: "var(--fic-touch-min)" },
      minWidth: { touch: "var(--fic-touch-min)" },
    },
  },
};

export default ficPreset;
