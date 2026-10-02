import type { Config } from "tailwindcss";

/**
 * Preset de marca MP Micropréstamos. Fuente única de valores: styles/tokens.css.
 * Brief 02: en tailwind.config.ts usar `presets: [mpPreset]` e importar styles/tokens.css en app/globals.css.
 * Nota: al referenciar variables CSS, los modificadores de opacidad de Tailwind (bg-mp-azul/50) no aplican;
 * si el Brief 02 los necesita, exponer canales RGB en tokens.css y usar `rgb(var(--x) / <alpha-value>)`.
 */
const mpPreset: Partial<Config> = {
  theme: {
    // Regla §15: una sola sombra. Se define fuera de extend para retirar shadow-md/lg/xl/2xl de Tailwind.
    boxShadow: { none: "none", sm: "var(--mp-shadow-sm)" },
    extend: {
      colors: {
        mp: {
          azul: "var(--mp-azul)",
          "azul-900": "var(--mp-azul-900)",
          "azul-50": "var(--mp-azul-50)",
          acento: "var(--mp-acento)",
          "acento-700": "var(--mp-acento-700)",
          "acento-100": "var(--mp-acento-100)",
          "acento-claro": "var(--mp-acento-claro)",
          blanco: "var(--mp-blanco)",
          "gris-100": "var(--mp-gris-100)",
          "gris-200": "var(--mp-gris-200)",
          "gris-300": "var(--mp-gris-300)",
          "gris-400": "var(--mp-gris-400)",
          "gris-600": "var(--mp-gris-600)",
          texto: "var(--mp-texto)",
          exito: "var(--mp-exito)",
          alerta: "var(--mp-alerta)",
          error: "var(--mp-error)",
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
        sans: ["var(--mp-font-sans)"],
        mono: ["var(--mp-font-mono)"],
      },
      fontSize: {
        xs: ["var(--mp-text-xs)", { lineHeight: "var(--mp-leading-normal)" }],
        sm: ["var(--mp-text-sm)", { lineHeight: "var(--mp-leading-normal)" }],
        base: ["var(--mp-text-base)", { lineHeight: "var(--mp-leading-normal)" }],
        lg: ["var(--mp-text-lg)", { lineHeight: "var(--mp-leading-normal)" }],
        xl: ["var(--mp-text-xl)", { lineHeight: "var(--mp-leading-tight)" }],
        "2xl": ["var(--mp-text-2xl)", { lineHeight: "var(--mp-leading-tight)" }],
        "3xl": ["var(--mp-text-3xl)", { lineHeight: "var(--mp-leading-tight)" }],
      },
      borderRadius: {
        sm: "var(--mp-radius-sm)",
        md: "var(--mp-radius-md)",
        lg: "var(--mp-radius-lg)",
      },
      minHeight: { touch: "var(--mp-touch-min)" },
      minWidth: { touch: "var(--mp-touch-min)" },
    },
  },
};

export default mpPreset;
