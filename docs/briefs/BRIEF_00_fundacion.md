# Brief 00 — Fundación, riesgos y sistema de diseño
<!-- Paquete: v5 — 01-oct-2026 -->
**Modo:** aprobación manual · **Duración estimada:** medio día

## Objetivo
Dejar el repositorio, las decisiones y el sistema de diseño listos para que los briefs siguientes solo construyan.

## Tareas
1. **Repo** `mp-app`: inicializar, `.gitignore`, `CLAUDE.md` (entregado), `docs/00_PROMPT_MAESTRO.md`, `docs/briefs/`, `docs/design/`.
2. **Risk assessment** (skill `operations:risk-assessment`) sobre: desembolso a cuenta equivocada, doble desembolso, solicitud aprobada sin aval de RRHH (Camino B), fuga de PII, caída de N8N a mitad de flujo, token Zoho vencido, discrepancia Supabase↔CRM. Incluir: desembolso accidental por pruebas contra BG LIVE, y parámetro financiero mal configurado por un usuario. Por cada riesgo: control preventivo, control detectivo y en qué brief se implementa. Guardar en `docs/RIESGOS.md`.
3. **Inventario del proceso actual** usando los MCP, sin modificar nada:
   - n8n: listar workflows de micropréstamo y el de BG H2H (anotar ID, nodos, credenciales, estructura del payload de la transferencia).
   - Zoho CRM: API names reales de `Afiliados` y `Solicitudes_Microprestamo`, picklists de estado, campos de tasa/WD IDs.
   - LoanDisk: `loan_product_id`, `loan_disbursed_by_id`, `loan_payment_scheme_id` tal como los usa el flujo vigente (`5wHL8Ut1ZT8SUZ2B`).
   - **Cómo viaja hoy la tasa** de CRM `Afiliados.Taza_de_Interes` hasta `loan_interest` en LoanDisk, y cómo se calculan plazo, frecuencia, FECI y fees. Reproducir con esos valores el préstamo 16860 (300.00 → 420.00) y SO-00077 ($100, 24 %, 6 cuotas de 28.67) en una prueba.
   - Deluge de fecha de inicio de descuento (regla de la quincena) y `Frecuencia_de_Planilla` de Afiliados: documentar la lógica exacta para replicarla en §4.6.
   - LoanDisk: esquemas de pago existentes (4418 = 15-30; confirmar si ya existe 10-25).
   - Workflows vigentes de la v1: 04 `HeXyYSjeUXu5qTBi`, 05 v2 `iPM3haUtdcof745M`, 06 prod `GTFFlEfXa0LOTtnF` (**no ejecutar ni modificar**), 06 QA `EQOqUBQp1N60zFlG`. Documentar payload BG y el uso de `bg_ambiente`.
   - Deluge `mp_enviar_a_zoho_sign1` (sobre único con `templates/mergesend`) y préstamo de referencia LoanDisk 11909610 (§18).
   - Zoho Sign: IDs y campos de merge de los 4 templates.
   Guardar todo en `docs/INVENTARIO_ACTUAL.md`. **Solo lectura.**
4. **Sistema de diseño**: incorporar las 5 pantallas aprobadas en Claude Design a `docs/design/`, generar `styles/tokens.css` con los tokens de §15 y la configuración de Tailwind.
5. **Cuentas y accesos**: confirmar SSH al VPS desde VS Code, DNS `mp.isthmuscap.com`, proyecto Supabase `isthmus-mp` creado, token de WhatsApp guardado en `.env` y en la credencial N8N `Meta WhatsApp MP` (plantilla ya aprobada; datos en §14).

## Criterio de aceptación
- `docs/RIESGOS.md` e `docs/INVENTARIO_ACTUAL.md` completos, con los IDs de LoanDisk y la estructura real del payload BG documentados.
- `styles/tokens.css` aplicado en una página de prueba que muestra logo, colores y tipografía.
- Ningún workflow ni registro de producción modificado.
