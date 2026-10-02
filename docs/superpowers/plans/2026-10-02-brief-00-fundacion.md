# Brief 00 — Fundación: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dejar repo, riesgos, inventario del proceso v1 y sistema de diseño listos para que los Briefs 01+ solo construyan, sin modificar ningún sistema externo.

**Architecture:** Brief documental. Tres entregables de texto (`docs/RIESGOS.md`, `docs/INVENTARIO_ACTUAL.md`, `docs/design/README.md`), un script de reproducción de la letra (`tests/inventario/letra_v1.mjs`) y el sistema de diseño (`styles/tokens.css`, `styles/tailwind.preset.ts`, `docs/design/preview.html`). Todo el inventario se obtiene por MCP en modo lectura y se enmascara la PII antes de escribirla.

**Tech Stack:** Markdown, Node 22 (script ESM sin dependencias), CSS custom properties, Tailwind preset (TypeScript, se cablea en Brief 02), Playwright MCP para capturas.

**Spec:** `docs/briefs/BRIEF_00_fundacion.md` + `docs/00_PROMPT_MAESTRO.md` §4.4, §4.6, §13, §15, §18 + precisiones de Gianclaudio (02-oct-2026, sesión de brainstorming).

## Global Constraints

- N8N: solo `get_workflow_details`, `list_credentials`, `search_workflows`, `search_workflow_executions`, `get_workflow_execution`. Prohibido `execute_workflow`, `test_workflow`, `prepare_workflow_pin_data`, `update_workflow`, `publish_workflow`, `unpublish_workflow`, `archive_workflow`. 06 prod `GTFFlEfXa0LOTtnF` es BG en producción: solo lectura.
- Supabase: proyecto `isthmus-mp` no existe (pendiente upgrade a Pro). No crear proyectos ni aplicar migraciones. Solo `list_organizations` / `list_projects`.
- Zoho CRM, Sign, WorkDrive, Creator, Monday: solo lectura (`get*`, `search*`, COQL).
- Secretos: nunca imprimir `WHATSAPP_TOKEN` ni ningún header/token de nodos N8N. Solo nombres e IDs de credenciales.
- PII: cédulas, cuentas de clientes, teléfonos y nombres de solicitantes enmascarados en docs y capturas.
- Idioma: docs en español (Panamá); commits en inglés.
- Nada financiero fijo: el inventario documenta valores; no los convierte en constantes de código.
- Redondeo de la letra: fuente de verdad = calendario que devuelve LoanDisk. El snapshot se reconcilia con LoanDisk después de crear el préstamo; no se recalcula por fórmula (regla para Brief 06).
- Tipografía: Manrope como propuesta, sujeta a la sesión de diseño con Diego antes del Brief 02. Estados del préstamo definidos con la paleta FIC y un mapeo estado→token; sin dependencia de los colores de LoanDisk.

## Review Focus

1. Un nodo HTTP del 05 v2 o 06 contiene un token en headers: el inventario debe omitirlo. Test: `grep -Ei 'bearer|zoho-oauthtoken|authorization' docs/INVENTARIO_ACTUAL.md` devuelve 0 líneas (Task 5).
2. El script de letra reproduce la fórmula de §4.6 y el resultado difiere de LoanDisk en centavos: el doc debe mostrar ambas cifras y la regla de reconciliación, no "corregir" la fórmula. Test: salida del script muestra `172.02` por fórmula y la tabla del doc muestra `172.00` LoanDisk (Task 4).
3. Una captura de Playwright incluye datos reales: la página de prueba solo usa datos ficticios etiquetados como ejemplo. Test: `grep -c 'Ejemplo' docs/design/preview.html` ≥ 1 y ninguna cédula con formato `[0-9]-[0-9]{3}-[0-9]{4}` (Task 7).
4. `tokens.css` contradice §15: los 8 hex deben coincidir literalmente. Test: `grep -c -E '#193A76|#66A5E6|#0F2650|#F4F6FA|#5B6472|#1F7A4D|#B45309|#B42318' styles/tokens.css` = 8 (Task 7).
5. `.env` se cuela en el commit: test `git status --porcelain | grep -c '\.env'` = 0 antes de commitear (Task 9).

---

### Task 1: Estructura de carpetas y plan

**Files:**
- Create: `docs/superpowers/plans/2026-10-02-brief-00-fundacion.md` (este archivo)
- Create: `docs/design/`, `docs/design/capturas/`, `styles/`, `tests/inventario/`

- [ ] **Step 1: Crear carpetas**

```bash
mkdir -p docs/superpowers/plans docs/design/capturas styles tests/inventario
```

- [ ] **Step 2: Verificar**

Run: `ls -d docs/design docs/design/capturas styles tests/inventario`
Expected: las 4 rutas listadas.

---

### Task 2: Inventario N8N (solo lectura)

**Files:**
- Create: `docs/inventario/n8n_raw_notes.md` (notas de trabajo, se consolidan en Task 5 y se borran)

**Interfaces:**
- Produces: lista de workflows MP con ID, nombre, estado activo, nodos (nombre + tipo), credenciales referenciadas (nombre + ID), estructura del payload BG, uso de `bg_ambiente`, IDs LoanDisk (`loan_product_id`, `loan_disbursed_by_id`, `loan_payment_scheme_id`, `branch_id`), expresión que construye `loan_interest`, `loan_duration`, `loan_duration_period`, fees/FECI.

- [ ] **Step 1: Buscar workflows**

MCP `n8n.search_workflows` con consultas: `MP`, `micro`, `BG`, `LoanDisk`, `Sign`, `05`, `06`, `07`.

- [ ] **Step 2: Detalle de cada workflow**

MCP `n8n.get_workflow_details` para `HeXyYSjeUXu5qTBi` (04), `iPM3haUtdcof745M` (05 v2), `GTFFlEfXa0LOTtnF` (06 prod), `EQOqUBQp1N60zFlG` (06 QA), `5wHL8Ut1ZT8SUZ2B` (flujo vigente LoanDisk) y cualquier otro MP encontrado en Step 1 (07 polling, sign events, carta firmada).

- [ ] **Step 3: Credenciales**

MCP `n8n.list_credentials`. Registrar nombre, ID y tipo. Confirmar `V8ToVmg60xSjZasl`, `lRBD9utZoqJjYHEW`, `l3e9P4UxBqKXKir4` y si existe `Meta WhatsApp MP`.

- [ ] **Step 4: Una ejecución real del 05 v2**

MCP `n8n.search_workflow_executions` (workflow `iPM3haUtdcof745M`, status success, límite 3) y `n8n.get_workflow_execution` de la más reciente. Extraer solo la estructura del payload LoanDisk y BG con valores enmascarados.

- [ ] **Step 5: Verificar que no se copió ningún secreto**

Run: `grep -Ei 'bearer|oauthtoken|authorization|api[_-]?key' docs/inventario/n8n_raw_notes.md`
Expected: 0 coincidencias (o solo la palabra como nombre de campo, sin valor).

---

### Task 3: Inventario Zoho CRM, Sign, Monday y Supabase (solo lectura)

**Files:**
- Create: `docs/inventario/zoho_raw_notes.md` (notas de trabajo, se consolidan en Task 5 y se borran)

**Interfaces:**
- Produces: API names y picklists de `Afiliados` y `Solicitudes_Microprestamo`; reglas de workflow que disparan Deluge; valores reales (enmascarados) de SO-00077 y SO-00078; campos de merge de los 4 templates de Sign; tablero Monday referenciado por 06; organizaciones/proyectos Supabase.

- [ ] **Step 1: Módulos y campos CRM**

MCP `Zoho_CRM_2.getModules` (confirmar API names). `getFields` de `Afiliados` y `Solicitudes_Microprestamo`. Registrar: `api_name`, `field_label`, `data_type`, `pick_list_values` para `Estado`, `Frecuencia_de_Planilla`, `Modo_Validacion`, `Estado_del_Contrato`; campos `Taza_de_Interes`, `Tasa_de_Comisi_n`, `WD_*`, `Sign_Request_ID_*`, `IDAnalyzer_Session_ID`, `NUC`.

- [ ] **Step 2: Reglas de workflow CRM**

MCP `Zoho_CRM.ZohoCRM_getWorkflowRules` para ambos módulos. Anotar reglas que llaman funciones (`mp_enviar_a_zoho_sign1`, inicio de descuento, carpetas).

- [ ] **Step 3: Registros de referencia**

COQL: `select Name, ... from Solicitudes_Microprestamo where Name in ('SO-00077','SO-00078')` con los campos de monto, tasa, plazo, fecha de inicio de descuento, fecha de solicitud, ciclo. Enmascarar cédula, cuenta y nombre.

- [ ] **Step 4: Zoho Sign**

MCP `Zoho_Sign_MCP.ZohoSign_getTemplateDetails` para `561993000000057083`, `561993000000058038`, `561993000000058099`, `561993000000058138`. Registrar nombre, acciones/firmantes y `field_label`/`field_name` de los campos de merge.

- [ ] **Step 5: Monday (solo si el 06 lo referencia)**

MCP `monday_com.get_board_info` del board ID encontrado en el trigger del 06. Registrar columnas usadas por el payload BG.

- [ ] **Step 6: Supabase**

MCP `Supabase.list_organizations` y `list_projects`. Confirmar que `isthmus-mp` no existe y anotar plan de la organización.

- [ ] **Step 7: Artefacto FECI**

`Artifact read` de `https://claude.ai/artifact/YBfCAUCeXcKKc6ZRL4CbiY` (LoanDisk FECI Configuration Guide). Extraer cómo se configuran FECI y fees en LoanDisk.

---

### Task 4: Reproducción de la letra v1

**Files:**
- Create: `tests/inventario/letra_v1.mjs`

**Interfaces:**
- Produces: `cuotaQuincenal({ monto, tasaMensualPct, plazoMeses })` → `{ cuotas, cuota, totalFormula, totalInteresSimple }`; `letraFlat({ monto, tasaMensualPct, cuotas })` para el caso 16860 (5 cuotas, no derivadas de meses).

- [ ] **Step 1: Escribir el script con casos esperados**

```js
// tests/inventario/letra_v1.mjs
// Reproduce la fórmula §4.6-a del Prompt Maestro y la contrasta con los valores reales de LoanDisk.
// No es el motor de reglas (Brief 06); es evidencia del inventario del Brief 00.
const r2 = (x) => Math.round((x + Number.EPSILON) * 100) / 100;

export function cuotaQuincenal({ monto, tasaMensualPct, plazoMeses }) {
  const cuotas = plazoMeses * 2;
  const cuota = r2(monto / cuotas + (monto * tasaMensualPct) / 100 / 2);
  return {
    cuotas,
    cuota,
    totalFormula: r2(cuota * cuotas),                       // cuota × cuotas (texto §4.6-a)
    totalInteresSimple: r2(monto + (monto * tasaMensualPct * plazoMeses) / 100), // capital + interés flat
  };
}

export function letraFlat({ monto, tasaMensualPct, cuotas }) {
  const meses = cuotas / 2;
  const cuota = r2(monto / cuotas + (monto * tasaMensualPct) / 100 / 2);
  return { cuotas, cuota, totalFormula: r2(cuota * cuotas), totalInteresSimple: r2(monto + (monto * tasaMensualPct * meses) / 100) };
}

const casos = [
  { id: "SO-00077 / 11909610", esperadoLoanDisk: { cuota: 28.67, total: 172.0 }, calc: cuotaQuincenal({ monto: 100, tasaMensualPct: 24, plazoMeses: 3 }) },
  { id: "16860",               esperadoLoanDisk: { cuota: 84.0,  total: 420.0 }, calc: letraFlat({ monto: 300, tasaMensualPct: 16, cuotas: 5 }) },
  { id: "§4.6 $300 4% 3m",     esperadoLoanDisk: { cuota: 56.0,  total: 336.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 3 }) },
  { id: "§4.6 $300 4% 6m",     esperadoLoanDisk: { cuota: 31.0,  total: 372.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 6 }) },
  { id: "§4.6 $300 4% 9m",     esperadoLoanDisk: { cuota: 22.67, total: 408.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 9 }) },
  { id: "§4.6 $300 4% 12m",    esperadoLoanDisk: { cuota: 18.5,  total: 444.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 12 }) },
];

let fallos = 0;
for (const c of casos) {
  const okCuota = c.calc.cuota === c.esperadoLoanDisk.cuota;
  const okTotalFormula = c.calc.totalFormula === c.esperadoLoanDisk.total;
  const okTotalSimple = c.calc.totalInteresSimple === c.esperadoLoanDisk.total;
  if (!okCuota || !okTotalSimple) fallos++;
  console.log(
    `${c.id.padEnd(24)} cuotas=${c.calc.cuotas} cuota=${c.calc.cuota.toFixed(2)} (${okCuota ? "OK" : "DIF"})` +
    ` total_formula=${c.calc.totalFormula.toFixed(2)} (${okTotalFormula ? "OK" : "DIF " + (c.calc.totalFormula - c.esperadoLoanDisk.total).toFixed(2)})` +
    ` total_interes_simple=${c.calc.totalInteresSimple.toFixed(2)} (${okTotalSimple ? "OK" : "DIF"})`
  );
}
console.log(fallos === 0 ? "\nCuota y capital+interés coinciden con LoanDisk en todos los casos." : `\n${fallos} caso(s) con diferencia en cuota o capital+interés.`);
process.exit(fallos === 0 ? 0 : 1);
```

- [ ] **Step 2: Ejecutar**

Run: `node tests/inventario/letra_v1.mjs`
Expected: exit 0; SO-00077 muestra `total_formula=172.02 (DIF 0.02)` y `total_interes_simple=172.00 (OK)`; 9m muestra `408.06 (DIF 0.06)` y `408.00 (OK)`; los demás OK.

- [ ] **Step 3: Documentar el hallazgo**

En `docs/INVENTARIO_ACTUAL.md` (Task 5) sección "Letra y redondeo": la cuota de §4.6 coincide; `cuota × cuotas` difiere en centavos del total de LoanDisk; LoanDisk reparte la diferencia según su calendario (verificar en el calendario del préstamo 11909610 si la última cuota absorbe los centavos). Regla Brief 06: el snapshot guarda el calendario devuelto por LoanDisk tras crear el préstamo; `/api/quote` muestra cuota y total estimado y los marca como estimados hasta la reconciliación.

---

### Task 5: `docs/INVENTARIO_ACTUAL.md`

**Files:**
- Create: `docs/INVENTARIO_ACTUAL.md`
- Delete: `docs/inventario/*_raw_notes.md` (después de consolidar)

- [ ] **Step 1: Escribir el documento con esta estructura**

```
# Inventario del proceso actual (v1 Zoho + N8N) — Brief 00
Fecha, alcance, política de enmascarado, lista de herramientas usadas (solo lectura).
1. Workflows N8N (tabla: nombre, ID, activo, trigger, función; luego ficha por workflow con nodos, credenciales, notas)
2. Banco General H2H: payload de transferencia (estructura, campos, origen de cada valor), `bg_ambiente`, diferencias 06 prod vs 06 QA
3. LoanDisk: IDs tal como viajan en los nodos (producto, esquema de pago por ciclo, disbursed_by, branch), método de interés, fees/FECI, préstamo de referencia 11909610
4. Tasa: camino CRM `Taza_de_Interes` → N8N → `loan_interest`; cálculo de plazo, frecuencia, cuotas
5. Letra y redondeo (salida del script de Task 4 + regla para Brief 06)
6. Zoho CRM: API names de `Afiliados` y `Solicitudes_Microprestamo`, picklists, campos tasa/WD/Sign/KYC, reglas de workflow
7. Deluge: funciones identificadas, qué regla las dispara, comportamiento observado; código fuente pendiente (Gianclaudio pegará `mp_enviar_a_zoho_sign1`)
8. Zoho Sign: 4 templates con campos de merge
9. Monday (solo lectura): tablero y columnas usadas por 06
10. Supabase: estado de la organización y del proyecto `isthmus-mp`
11. Accesos (Task 8)
12. Pendientes y bloqueantes detectados
```

- [ ] **Step 2: Verificar que no hay secretos ni PII cruda**

Run: `grep -Ei 'bearer|oauthtoken|authorization: ' docs/INVENTARIO_ACTUAL.md | wc -l` → 0
Run: `grep -E '\b[0-9]{1,2}-[0-9]{3,4}-[0-9]{3,6}\b' docs/INVENTARIO_ACTUAL.md | wc -l` → 0 (cédulas completas)

- [ ] **Step 3: Borrar notas de trabajo**

Run: `rm -rf docs/inventario`

---

### Task 6: `docs/RIESGOS.md`

**Files:**
- Create: `docs/RIESGOS.md`

- [ ] **Step 1: Invocar `operations:risk-assessment`** y seguir su estructura.

- [ ] **Step 2: Escribir los 12 riesgos** (9 del brief + 3 de Gianclaudio), cada uno con: descripción, probabilidad, impacto, control preventivo, control detectivo, brief que lo implementa, estado hoy.

Lista: (1) desembolso a cuenta equivocada, (2) doble desembolso, (3) aprobación sin aval RRHH en Camino B, (4) fuga de PII, (5) caída de N8N a mitad de flujo, (6) token Zoho vencido, (7) discrepancia Supabase↔CRM, (8) desembolso accidental por pruebas contra BG LIVE, (9) parámetro financiero mal configurado, (10) Supabase en plan Free: pausa por inactividad y sin backups diarios, bloqueante para producción, (11) repo sin remoto: fallo del VPS pierde el código, (12) sesión de Claude Code con acceso a N8N con BG LIVE.

Más una sección "Riesgos detectados en el inventario" con lo que aparezca en Tasks 2 a 4.

- [ ] **Step 3: Verificar**

Run: `grep -c '^### R' docs/RIESGOS.md` → ≥ 12

---

### Task 7: Sistema de diseño

**Files:**
- Create: `styles/tokens.css`
- Create: `styles/tailwind.preset.ts`
- Create: `docs/design/preview.html`
- Create: `docs/design/README.md`
- Create: `docs/design/capturas/preview-390.png`, `docs/design/capturas/preview-1440.png`

**Interfaces:**
- Produces: variables CSS `--fic-*` y `--estado-*`; preset Tailwind `ficPreset` que el Brief 02 importa con `presets: [ficPreset]` en `tailwind.config.ts`.

- [ ] **Step 1: `styles/tokens.css`**

```css
/* FIC — tokens de marca. Fuente: docs/00_PROMPT_MAESTRO.md §15. Tipografía propuesta (Manrope) sujeta a la sesión de diseño con Diego antes del Brief 02. */
:root {
  /* Marca (§15, literal) */
  --fic-azul:        #193A76;
  --fic-azul-claro:  #66A5E6;
  --fic-azul-900:    #0F2650;
  --fic-gris-100:    #F4F6FA;
  --fic-gris-600:    #5B6472;
  --fic-exito:       #1F7A4D;
  --fic-alerta:      #B45309;
  --fic-error:       #B42318;

  /* Neutros derivados (propuesta Brief 00; no están en §15) */
  --fic-blanco:      #FFFFFF;
  --fic-gris-200:    #E3E8F0;   /* bordes, divisores */
  --fic-gris-300:    #C9D2DF;   /* bordes de inputs */
  --fic-texto:       #16213A;   /* texto principal */

  /* Tipografía */
  --fic-font-sans: "Manrope", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  --fic-font-mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  --fic-text-xs: 0.75rem;  --fic-text-sm: 0.875rem; --fic-text-base: 1rem;
  --fic-text-lg: 1.125rem; --fic-text-xl: 1.375rem; --fic-text-2xl: 1.75rem; --fic-text-3xl: 2.25rem;
  --fic-leading-tight: 1.2; --fic-leading-normal: 1.5;

  /* Forma */
  --fic-radius-sm: 6px; --fic-radius-md: 10px; --fic-radius-lg: 16px;
  --fic-shadow-sm: 0 1px 2px rgba(15, 38, 80, 0.06);   /* única sombra permitida */
  --fic-touch-min: 44px;                                /* §9: tamaño de toque mínimo */

  /* Estados del préstamo (nombres de LoanDisk, colores FIC). Mapeo estado→token. */
  --estado-current:        var(--fic-exito);
  --estado-due-today:      var(--fic-azul-claro);
  --estado-missed:         var(--fic-alerta);
  --estado-arrears:        var(--fic-error);
  --estado-past-maturity:  var(--fic-azul-900);
}
```

- [ ] **Step 2: `styles/tailwind.preset.ts`**

```ts
import type { Config } from "tailwindcss";

/** Preset FIC. Brief 02: `presets: [ficPreset]` en tailwind.config.ts e importar styles/tokens.css en app/globals.css. */
const ficPreset: Partial<Config> = {
  theme: {
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
      fontFamily: { sans: ["var(--fic-font-sans)"], mono: ["var(--fic-font-mono)"] },
      borderRadius: { sm: "var(--fic-radius-sm)", md: "var(--fic-radius-md)", lg: "var(--fic-radius-lg)" },
      boxShadow: { sm: "var(--fic-shadow-sm)" },
      minHeight: { touch: "var(--fic-touch-min)" },
      minWidth: { touch: "var(--fic-touch-min)" },
    },
  },
};

export default ficPreset;
```

- [ ] **Step 3: `docs/design/preview.html`** — página estática que enlaza `../../styles/tokens.css`, carga Manrope desde Google Fonts, muestra logo, 8 colores de marca, neutros, escala tipográfica, botones primario/secundario, badges de los 5 estados y una tarjeta con datos de ejemplo ficticios (etiquetados "Ejemplo").

- [ ] **Step 4: Servir y capturar**

Run: `python3 -m http.server 8765 --bind 127.0.0.1 --directory /opt/mp-app &`
Playwright MCP: `browser_resize` 390×844 → `browser_navigate` `http://127.0.0.1:8765/docs/design/preview.html` → `browser_take_screenshot` → `docs/design/capturas/preview-390.png`; repetir a 1440×900 → `preview-1440.png`. Matar el servidor.

- [ ] **Step 5: `docs/design/README.md`** — índice: estado de las 5 pantallas (pendientes antes del Brief 02, §15), tokens, preset, cómo cablear en Brief 02, capturas, decisiones (Manrope propuesta; estados con paleta FIC).

- [ ] **Step 6: Verificar**

Run: `grep -c -E '#193A76|#66A5E6|#0F2650|#F4F6FA|#5B6472|#1F7A4D|#B45309|#B42318' styles/tokens.css` → 8
Run: `ls docs/design/capturas/` → 2 PNG

---

### Task 8: Cuentas y accesos

**Files:**
- Modify: `docs/INVENTARIO_ACTUAL.md` sección 11

- [ ] **Step 1: SSH** — ya confirmado: esta sesión corre en `5.78.214.136` (hostname `isthmus-n8n`) como root. Anotar que Brief 01 crea `deploy`.
- [ ] **Step 2: DNS** — Run: `dig +short mp.isthmuscap.com A; dig +short staging-mp.isthmuscap.com A; dig +short microprestamos.isthmuscap.com A`. Anotar resultado (esperado: apuntar a 5.78.214.136 o vacío → pendiente).
- [ ] **Step 3: Supabase** — resultado de Task 3 Step 6: pendiente upgrade Pro, bloqueante Brief 03.
- [ ] **Step 4: WhatsApp `.env`** — Run: `grep -E '^WHATSAPP_(PHONE_NUMBER_ID|BUSINESS_ACCOUNT_ID|APP_ID|TEMPLATE_OTP)=' .env` y comparar con §14 (`1184886231372996`, `4466216373701343`, `1360854289567229`, `fic_mp_codigo_acceso`). Nunca mostrar `WHATSAPP_TOKEN`; solo `grep -c '^WHATSAPP_TOKEN=' .env` → 1 y `stat -c %a .env` → 600.
- [ ] **Step 5: Credencial N8N `Meta WhatsApp MP`** — de Task 2 Step 3. Si no existe: pendiente para Gianclaudio.

---

### Task 9: Verificación y commit

- [ ] **Step 1: `verification-before-completion`** — releer criterio de aceptación del Brief 00 y mostrar evidencia: `node tests/inventario/letra_v1.mjs` (salida), `ls docs/design/capturas`, `wc -l docs/RIESGOS.md docs/INVENTARIO_ACTUAL.md`.
- [ ] **Step 2: Secretos fuera del commit** — Run: `git status --porcelain | grep -c '\.env'` → 0; `git grep -nE 'EAA[A-Za-z0-9]{20,}|1000\.[A-Za-z0-9]{32}' -- . ':!docs/00_PROMPT_MAESTRO.md'` → 0.
- [ ] **Step 3: Commit**

```bash
git add docs styles tests
git commit -m "docs(brief-00): risk register, v1 process inventory and FIC design tokens

- docs/RIESGOS.md: 12 risks with preventive/detective controls and owning brief
- docs/INVENTARIO_ACTUAL.md: read-only inventory of N8N, Zoho CRM/Sign, LoanDisk IDs, BG payload
- tests/inventario/letra_v1.mjs: reproduces v1 installment formula vs LoanDisk references
- styles/tokens.css + styles/tailwind.preset.ts + docs/design/preview.html

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 4: Resumen final** para Gianclaudio con pendientes y bloqueantes.
