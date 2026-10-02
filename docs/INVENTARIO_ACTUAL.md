# Inventario del proceso actual (v1 Zoho + N8N) — Brief 00
<!-- Paquete: v5 — Brief 00 — 02-oct-2026 -->

**Fecha:** 02-oct-2026. **Alcance:** lo que hoy mueve una solicitud de micropréstamo desde el formulario Creator hasta el desembolso BG, con los nombres reales (API names, IDs, picklists) que la app debe replicar. **Modo:** solo lectura; ningún workflow, registro ni configuración fue modificado.
**Enmascarado:** no se copian cédulas, cuentas, teléfonos, correos de solicitantes, salarios ni IDs de sesión KYC. Los IDs de registros, templates, carpetas y préstamos sí se documentan porque la app los necesita.
**Herramientas usadas (solo lectura):** Zoho CRM MCP (`getFields`, `getWorkflowRules`, `getWebhooks`, `getFieldUpdates`, COQL), Zoho Sign MCP (`getTemplateDetails`), Supabase MCP (`list_organizations`, `list_projects`), Monday MCP (`search`, `get_board_info`), Claude Docs (lectura de "LoanDisk FECI Configuration Guide" y "Proceso de Micropréstamos"), shell local (`dig`, `stat`, `grep`, `node`).

## 0. Estado del inventario

| Sección | Estado | Fuente |
|---|---|---|
| 1. Workflows N8N | **Bloqueado** (la cadena v1 se documenta en 1-bis con lo validado por Gianclaudio el 02-oct-2026 y por CRM/Sign; el 03 KYC corregido se describe según esa validación) | El MCP de n8n pide re-autenticación (OAuth, no posible en sesión no interactiva). La lectura directa de la base de n8n fue denegada por el clasificador de permisos de Claude Code. Lo que figura abajo viene de §2, §8 y §18 del Prompt Maestro y debe confirmarse contra los nodos reales. |
| 2. Payload BG | **Pendiente** (depende de 1) | Solo se documentan los campos CRM/Monday que lo alimentan. |
| 3. IDs LoanDisk | Parcial | Producto y ciclos de §18; branch por afiliado y números de préstamo confirmados en CRM; `loan_disbursed_by_id` y `loan_payment_scheme_id` tal como viajan: pendiente de 1. |
| 4. Tasa | Confirmado en CRM; tramo CRM→LoanDisk pendiente de 1 | COQL sobre SO-00077/78/79 y AF-0031/0033. |
| 5. Letra y redondeo | Completo | `tests/inventario/letra_v1.mjs` |
| 6. Zoho CRM | Completo | `getFields` + reglas + registros reales |
| 7. Deluge | Parcial | Reglas y comportamiento observado; código fuente pendiente (Gianclaudio pegará `mp_enviar_a_zoho_sign1`). |
| 8. Zoho Sign | Completo | 4 templates leídos |
| 9. Monday | Parcial | Tableros localizados; relación exacta con el 06 pendiente de 1. |
| 10. Supabase | Completo | Proyecto `isthmus-mp` no existe |
| 11. Accesos | Completo | Ver §11 |

## 1. Workflows N8N (pendiente de confirmación con el MCP)

| Workflow | ID | Función (según Prompt Maestro) | Qué falta capturar |
|---|---|---|---|
| 04 — guardar documentos firmados | `HeXyYSjeUXu5qTBi` | Webhook de Sign → descarga los 4 PDF por separado con nombre y certificado → WorkDrive; la Carta va también a RRHH (§18) | Nodos, credencial Zoho (debe ser `lRBD9utZoqJjYHEW` por usar WorkDrive), naming de archivos, campos CRM que escribe (`Sign_Status_*`, `Sign_Detalle_*`, `WorkDrive_Docs_Firmados_URL`) |
| 05 v2 — LoanDisk + decisión de ambiente BG | `iPM3haUtdcof745M` | Crea borrower + loan en LoanDisk; decide con `bg_ambiente = 'qa' \| 'prod'` a qué 06 llamar (§18) | **Payload LoanDisk completo**: `loan_product_id`, `loan_disbursed_by_id`, `loan_payment_scheme_id`, `loan_interest`, `loan_duration`, `loan_duration_period`, fees; expresión que lee la tasa; dónde vive `bg_ambiente`; nodo que escribe `Prestamo_No` en CRM |
| 06 prod — BG H2H producción | `GTFFlEfXa0LOTtnF` | Genera la transferencia pendiente en Banca en Línea que Diego aprueba o rechaza. **No se modifica ni se ejecuta.** | Trigger (Monday / webhook), **estructura del payload de transferencia**, credencial BG, cuenta origen, cómo devuelve `codigoPago` |
| 06 QA — BG H2H certificación | `EQOqUBQp1N60zFlG` | Ambiente `bg-h2h-qa2`, cuenta de certificación 0301011367700; probado OK con `codigoPago 12317` (§18) | Diferencias con el 06 prod (solo URL/cuenta/credencial, o también nodos) |
| Flujo vigente LoanDisk (Brief 00) | `5wHL8Ut1ZT8SUZ2B` | Referencia del Brief 00 para los IDs de LoanDisk | Confirmar si es el flujo Monday original del que el 05 v2 tomó los IDs |
| 07 — polling BG | ID desconocido | Estado de transferencias cada 10 min (§4.7, §8) | ID, nodos, campos CRM que actualiza (`Referencia_de_Transferencia`, `Aprobaciones_BG`) |
| `mp_sign_guardar_docs`, `mp-carta-firmada` | IDs desconocidos | Nombres citados en §8 como los que `mp_sign_events` reemplaza | Confirmar si son el 04 o workflows aparte |

Credenciales N8N citadas en el Prompt Maestro (pendiente confirmar con `list_credentials`): Zoho `V8ToVmg60xSjZasl` (sin WorkDrive), Zoho `lRBD9utZoqJjYHEW` (con WorkDrive, *Token Expired Status Code = 500*), Gmail `l3e9P4UxBqKXKir4` (gestionprestamos@isthmuscap.com), `Meta WhatsApp MP` (existencia sin confirmar).

**Checklist para completar esta sección** (cuando el conector n8n esté re-autenticado): `search_workflows` → `get_workflow_details` de los 5 IDs + 07 → `list_credentials` → `search_workflow_executions` del 05 v2 (status success, últimas 3) → `get_workflow_execution` de una con `includeData` solo para los nodos LoanDisk y BG. Copiar estructura, nunca headers ni valores de credenciales; enmascarar PII.

## 1-bis. Cadena v1 end-to-end — línea base funcional

**Estado validado (Gianclaudio, 02-oct-2026; fuente de verdad por encima de cualquier documento anterior):** el flujo MP v1 en Zoho + N8N está completo de punta a punta con **SO-00079**: WhatsApp → KYC → formulario → 4 documentos firmados (sobre único) → préstamo LoanDisk **11913796** → transferencia BG **código 18524** (pendiente de aprobación de Diego). Casos de referencia: **SO-00078 / 11909610** ($100, 24 %, 6 cuotas de 28.67) y **SO-00079 / 11913796** ($300, 24 %, 6 cuotas de 86.00). Es la **línea base funcional** de la app.

Cadena técnica: **03 KYC → 04 Sign (sobre único) → 05 v2 (`iPM3haUtdcof745M`, crea el préstamo en LoanDisk 383523) → 06 BG según `bg_ambiente`** (`qa` = `EQOqUBQp1N60zFlG`, `prod` = `GTFFlEfXa0LOTtnF`). El 06 se **reutiliza tal cual**: lo comparte con Seguridad Unida (Monday); la app lo llama igual que el 05 v2 y nunca lo modifica. **Orden real del cliente:** primero el WhatsApp con el enlace, luego el KYC y después el formulario; por eso el KYC llega normalmente **antes** de que exista la solicitud.

Leyenda: ✅ confirmado en CRM/Sign/registros · 📄 según Prompt Maestro §18 o contexto de Gianclaudio · ⏳ pendiente de ver en los nodos N8N (sección 1).

### Paso 0 — Entrada: formulario Creator → CRM

| | Detalle |
|---|---|
| Entradas | Formulario web de Zoho Creator (`Canal_de_Entrada = Formulario Web (Creator)` ✅). Datos personales, laborales, cuenta bancaria, monto (`100/150/200/300`), cuotas (`6`), aceptación de T&C con fecha/hora e IP (`Acepta_Terminos`, `Single_Line_24`, `Single_Line_25`), firma manuscrita (`Firma`, `Firma_Img`). |
| Validaciones | En Creator contra `Empleados_Report` (cédula existe en la base del afiliado, antigüedad ≥ 3 meses, descuentos actuales, capacidad) 📄 §1. **Se retiran con Creator**: la app las reimplementa en el motor de reglas (Brief 06) sobre `empleados_master`. |
| Salidas | Registro en `Solicitudes_Microprestamo` ✅ con: `ID_Solicitante` (`SO -000NN`), `ID_Afiliado`, tasa copiada del afiliado (`Tasa_Nominal = Tasa_Efectiva = Afiliados.Taza_de_Interes` ✅; quién la copia ⏳), `Letra_Mensual` (cuota quincenal ✅), `Fecha_Inicio_Descuento` (Deluge, regla de la quincena ✅), `LoanDisk_Branch_ID` heredado (regla CRM ✅), estado `Nueva → En Revision` (regla CRM ✅), 7 carpetas WorkDrive y sus URLs (Zoho Flow ✅). |
| Orden real | En el flujo del cliente el formulario llega **después** del KYC: el 03 envía por WhatsApp el enlace del formulario al aprobarse IDAnalyzer (Paso 1). |
| Observación | **No existe un campo NUC** en `Solicitudes_Microprestamo` ni en `Afiliados`; el NUC debe vivir en `Contacts` u otro módulo. Confirmar en el Brief 03/05 antes de `ensure_cliente`. |

### Paso 1 — 03 KYC (IDAnalyzer DocuPass) — corregido y publicado el 02-oct-2026

| | Detalle |
|---|---|
| Workflow | "03" (ID ⏳). Profile IDAnalyzer `53067a87b10a41bd8771c34e9b7c53c4` 📄 §2. Versión corregida publicada el 02-oct-2026; **aún no validada en vivo**: la valida el próximo KYC real. |
| Entradas | Callback de IDAnalyzer con el resultado de la verificación (cédula, sesión, estado aprobado/rechazado). Llega normalmente **antes** de que exista la solicitud. |
| Comportamiento (v1 corregida) | 1. Al **aprobar** IDAnalyzer, el **WhatsApp con el enlace del formulario sale de inmediato**, sin depender de encontrar la solicitud (antes dependía de ella y casi nunca salía). Si el WhatsApp falla, **no frena** lo demás. 2. En paralelo busca la solicitud por cédula; si no existe, **reintenta cada 2 min hasta 15 veces (30 min)**. 3. Sin solicitud a los 30 min → correo desde **gestionprestamos@** a Gisela y a Gianclaudio con la cédula y el enlace de la ejecución, para reprocesarla. 4. Si la encuentra: guarda `IDAnalyzer_Session_ID` en CRM ✅ (presente en SO-00078/79) y sube **3 reportes** (Transaction, Face, Docupass Audit) al folder KYC (`Folder_ID_KYC`). |
| Validaciones | Resultado/score de DocuPass; selfie con instrucción visual 📄 §4.1. |
| Salidas | WhatsApp al solicitante; `IDAnalyzer_Session_ID` (+ `IDAnalyzer_Transaction_ID`) en CRM; 3 PDF en `Folder_ID_KYC`; correo de excepción a operaciones si no hay solicitud. |
| Lección N8N | El **Retry** de N8N reutiliza la salida guardada del nodo anterior; para reprocesar hay que **re-ejecutar el workflow completo con el payload original**. Para la app: `webhook_inbox` conserva el payload original de cada callback y el reproceso siempre parte de él. |
| Regla para la app | El **OTP/enlace por WhatsApp no puede depender de que exista la solicitud**, y `mp_kyc_callback` debe tolerar el orden KYC → solicitud (asociación posterior por cédula/sesión con reintentos y alerta a operaciones), igual que la v1 corregida. |

### Paso 2 — Revisión y envío a firma (CRM + Deluge)

| | Detalle |
|---|---|
| Entradas | Analista revisa el expediente en CRM (`En Revision`) y cambia `Estado_Solicitud` a `Pendiente Firma`. |
| Disparo | Regla CRM "MP - Enviar Documentos a Firma" (field_update) ✅ → Deluge `mp_enviar_a_zoho_sign1` (conexión `zoho_sign`) 📄. |
| Salidas | Un solo sobre con los 4 templates vía `templates/mergeview` + `templates/mergesend` 📄; correo de firma a nombre de **Isthmus Capital** con el nombre del solicitante 📄; el **mismo `request_id`** en `Sign_Request_ID_Contrato/Pagare/Carta/APC` ✅ (`561993000000350144`, `561993000000360046`); `Sign_Status_* = IN PROGRESS` ✅. |
| Firmantes reales (templates) | Solicitante (SIGN) → Isthmus/Gisela (**APPROVER** en Contrato y Carta) → RRHH_Afiliado (SIGN, solo Carta) ✅. Discrepancia con §13.2: ver R13. |
| Campos de merge | Sección 8. Valores: monto, cuota quincenal (`cuota_mensual`), tasa nominal = efectiva, plazo (cuotas), `fecha_primer_pago` = `Fecha_Inicio_Descuento`, `monto_total`, montos en letras, empresa, ciudad, fecha dividida en día/mes/año. |

### Paso 3 — 04 Sign events (`HeXyYSjeUXu5qTBi`)

| | Detalle |
|---|---|
| Entradas | Webhook de Zoho Sign por evento del sobre (firmado parcial, completado, recalled). |
| Validaciones | ⏳ (idempotencia por `request_id` + evento; credencial Zoho con WorkDrive `lRBD9utZoqJjYHEW`, *Token Expired Status Code = 500* 📄). |
| Salidas | `Sign_Status_*` y `Sign_Detalle_*` por documento ✅ (`COMPLETED` ×4; `RECALLED` en SO-00077 cancelada). Al completarse: descarga de los **4 PDF por separado**, con nombre y certificado de firma, a `Folder_ID_Documentos_Firmados`; la Carta también a `Folder_ID_RRHH` 📄 §18; `WorkDrive_Docs_Firmados_URL` ✅ (campo). Dispara el 05 v2 ⏳ (directo o por cambio de estado). |

### Paso 4 — 05 v2 LoanDisk + decisión BG (`iPM3haUtdcof745M`)

| | Detalle |
|---|---|
| Entradas | Solicitud con 4 firmas completas: datos del solicitante (borrower), `Monto_Solicitado`, `Cuotas`, `Tasa_Nominal`, `Fecha_Inicio_Descuento`, `LoanDisk_Branch_ID`, ciclo del afiliado (`Frecuencia_de_Planilla`). |
| Validaciones | Ciclo con esquema LoanDisk (`10-25` → 4646, `15-30` → 4418); si no existe esquema, se detiene en desembolso pendiente con alerta 📄 §4.6-c. Nunca `Bimonthly` (12) 📄. |
| Salidas | Borrower + Loan en producto **383523** (Flat Rate) en el branch del afiliado ✅ (92588); `loan_interest` = tasa del afiliado 📄 (expresión ⏳); `Prestamo_No` escrito en CRM ✅ (11909610, 11913796); estado `Pendiente Desembolso` ✅. Decide `bg_ambiente` (`qa`/`prod`) y llama al 06 correspondiente 📄. |
| Correos | Salen de **gestionprestamos@isthmuscap.com** (credencial N8N Gmail "Gmail account 2" `l3e9P4UxBqKXKir4`), nunca de facturasfic@ 📄 §18. Destinatarios y plantillas por paso ⏳. |
| Cronograma | LoanDisk arma el calendario con el esquema del ciclo (6 cuotas de 28.67 el 10 y 25 de oct–dic para el 11909610, total 172.00) 📄; es la **fuente de verdad** del total y de las fechas (sección 5). |

### Paso 5 — 06 BG H2H (`EQOqUBQp1N60zFlG` QA / `GTFFlEfXa0LOTtnF` prod)

| | Detalle |
|---|---|
| Entradas | Beneficiario (nombre, cédula), banco destino (`Banco_Desembolso`), tipo y número de cuenta, monto, referencia de la solicitud, ambiente ⏳ (estructura exacta: sección 2). Mismo contrato de entrada que usa Seguridad Unida desde Monday 📄. |
| Comportamiento | QA: ambiente `bg-h2h-qa2`, cuenta de certificación, probado OK con `codigoPago 12317` 📄. Prod: crea la **transferencia pendiente** en Banca en Línea; Diego la aprueba o rechaza 📄. Credencial BG ⏳. |
| Salidas | `codigoPago` → `Aprobaciones_BG` ✅ (campo; vacío hoy en SO-00078/79 porque están `Pendiente Desembolso`); referencia → `Referencia_de_Transferencia`; estado `Desembolsada`; comprobante a `Folder_ID_Desembolso`; aviso a Gisela 📄 §13.3. Polling 07 cada 10 min para el estado final 📄. |
| Regla para la app | **Nunca modificar el 06.** `lib/banking` construye exactamente el mismo payload que envía el 05 v2 y lo manda al 06 que corresponda a `bg_ambiente`; staging y pruebas siempre `qa`. |

### Qué replica la app y qué mejora

| Replica tal cual | Mejora (decisiones §13, §16–18) |
|---|---|
| Sobre único de 4 documentos, mismo `request_id`, correo a nombre de Isthmus Capital | Un solo correo con los 4 PDF al solicitante; recordatorios 72 h / 7 d / 15 d; sin APPROVER en Sign (pendiente R13) |
| Tasa del afiliado como fuente única; cuota quincenal §4.6-a; inicio de descuento por ciclo | Parámetros administrables (plazos 3/6/9/12, montos, ciclos) sin tocar código; snapshot congelado por solicitud |
| LoanDisk 383523, esquemas 4646/4418, branch por afiliado, `Prestamo_No` en CRM | IDs en `parametros`, no en código; reconciliación del snapshot con el calendario de LoanDisk |
| 06 BG tal cual, con `bg_ambiente` | `dry_run` por defecto en staging; cola de desembolso con OTP para Diego; conciliación `bg_transacciones` |
| Correos desde gestionprestamos@ | WhatsApp como canal principal (plantillas UTILITY), email de respaldo, push PWA |
| Expediente en CRM (write-back de cada transición) | Estado operativo en Supabase; `webhook_inbox`/`outbox` idempotentes; `mp_reconcile_crm` nocturno |
| KYC IDAnalyzer con callback tolerante al orden (WhatsApp inmediato, búsqueda por cédula con reintentos 2 min × 15, correo de excepción a operaciones) | Adaptador `kyc_provider`; `webhook_inbox` con payload original para reproceso; reutilización de KYC vigente < 12 meses |
| OTP/enlace por WhatsApp independiente de la solicitud | Plantilla `fic_mp_codigo_acceso` + magic link de respaldo; la solicitud existe desde el paso 1 del wizard pero el canal nunca depende de ella |
| 7 carpetas WorkDrive por solicitud | 6 carpetas `01_KYC … 06_Desembolso` creadas por N8N (sin Zoho Flow); mapeo en Brief 08 |

## 2. Banco General H2H

- **Endpoint y cuentas (§2, §18):** `conexionbg.bgeneral.cloud`; cuenta origen producción `0301000001265`; QA `bg-h2h-qa2` con cuenta de certificación `0301011367700`.
- **Comportamiento del 06 prod:** no ejecuta la transferencia; la deja **pendiente de aprobación** en Banca en Línea, donde Diego (único firmante, §13.3) aprueba o rechaza. Esto es un control natural contra desembolsos erróneos y debe mantenerse en la app.
- **Selector de ambiente:** `bg_ambiente ∈ {qa, prod}` decidido en el 05 v2. La app usa el mismo parámetro; staging y pruebas siempre `qa`.
- **Campos CRM relacionados con BG (API names reales):** `Aprobaciones_BG` (etiqueta "Codigo Pago", integer), `Referencia_de_Transferencia` (etiqueta "Confirmacion", text), `Banco_Desembolso` (picklist: Banco General, BAC, Banistmo, Caja de Ahorros, Banco Nacional, Global Bank), `Tipo_de_Cuenta` (Cuenta de Ahorros / Cuenta Corriente), `Es_Titular_de_la_Cuenta` (Si/No), `Numero_de_Cuenta` (text), `Titular_Cuenta_Completo` (text), `Folder_ID_Desembolso`, `WorkDrive_Desembolso_URL`.
- **Observado:** al 01-oct-2026 11:09 `Aprobaciones_BG` estaba vacío en SO-00078/79. El 02-oct-2026 SO-00079 generó la transferencia BG con **código 18524**, pendiente de aprobación de Diego en Banca en Línea (validado por Gianclaudio). El `codigoPago 12317` de la prueba QA no quedó en CRM. Confirmar en el Brief 12 que el 07 escribe el código en `Aprobaciones_BG` y la referencia en `Referencia_de_Transferencia`.
- **Estructura del payload de transferencia:** **pendiente** (sección 1). Hipótesis a confirmar: nombre + apellido del beneficiario, cédula, banco destino (código BG), tipo de cuenta, número de cuenta, monto, referencia/descripción, cuenta origen, ambiente.

## 3. LoanDisk

| Dato | Valor | Fuente | Estado |
|---|---|---|---|
| Producto | `383523` "Micropago Flat 1025", Flat Rate, interés sobre el monto original, cuota constante; rango de interés del producto min 18 / max 30 | §18 | Confirmar en nodo del 05 v2 |
| Productos que **no** se usan | 369108, 369109, 383112 | §18 | — |
| Ciclo 10-25 | `loan_payment_scheme_id = 4646` | §18 | Confirmar en nodo |
| Ciclo 15-30 | `loan_payment_scheme_id = 4418`; pendiente habilitarlo en el producto 383523 | §18, §17 | Pendiente Gisela |
| Ciclo prohibido | `Bimonthly` (ID 12): por API genera cuotas cada 2 meses | §18 | Regla en `parametros` |
| Branch por afiliado | AF-0033 → `92588`; AF-0031 → `91008` | CRM `Afiliados.LoanDisk_Branch_ID` | Confirmado |
| Herencia del branch a la solicitud | Regla CRM "LoanDisk_BranchID" (create) copia `Afiliados.LoanDisk_Branch_ID` a `Solicitudes_Microprestamo.LoanDisk_Branch_ID` | `getWorkflowRules` | Confirmado (SO-00077/78/79 = 92588) |
| Cuenta LoanDisk | Public Key `75055`, Branch principal `87572` | §2 | — |
| `loan_disbursed_by_id` | Pendiente | Nodo del 05 v2 | **Pendiente** |
| Número de préstamo | Se guarda en CRM `Prestamo_No` (bigint): SO-00078 → `11909610` (referencia §18), SO-00079 → `11913796` | COQL | Confirmado |
| Casos de referencia v1 | **SO-00078 / 11909610** ($100, 24 %, 6 × 28.67, total 172.00) y **SO-00079 / 11913796** ($300, 24 %, 6 × 86.00, total 516.00; BG código 18524) | Gianclaudio 02-oct-2026 + COQL | Confirmado |
| Préstamo histórico de referencia | `16860`: 300.00 → 420.00, 16 %/mes, 5 cuotas de 84.00 | §4.4 | Reproducido en §5 |
| **FECI** | **Exento** para micropréstamos: regla "Small loan: monto original ≤ B/.5,000 → FECI 0 %". El fee "FECI %" (ID `15489`) existe en la cuenta y no debe adjuntarse. | Doc "LoanDisk FECI Configuration Guide" (01-oct-2026) | Confirmado; parámetro de producto `feci_pct = 0` |
| Comisión de cierre, timbres, seguro | Pendiente | Nodo del 05 v2 (fees) | **Pendiente** |
| Campos CRM LoanDisk en `Afiliados` sin uso | `Loan_Product`, `Number_of_Payments`, `Repayment_Cycle` (text, vacíos en AF-0031 y AF-0033) | `getFields` + COQL | Documentado; no son fuente |

**Regla (reconfirmada el 02-oct-2026):** las pruebas manuales en LoanDisk **nunca** usan números `SO-` ni numeración en secuencia: un préstamo de prueba creado como "SO -00079" bloqueó el préstamo real de SO-00079. Usar prefijo propio (p. ej. `TEST-`) y branch de pruebas.

## 4. Cómo viaja la tasa

```
CRM Afiliados.Taza_de_Interes (percent; Diego la coloca)
   └─(copia al crear la solicitud: Creator/Deluge o N8N — tramo PENDIENTE de confirmar)─▶
CRM Solicitudes_Microprestamo.Tasa_Nominal = Tasa_Efectiva (percent)
   └─(05 v2 iPM3haUtdcof745M — expresión PENDIENTE)─▶ LoanDisk loan_interest
```

Evidencia:
- AF-0033 "Prueba Inc." tiene `Taza_de_Interes = 24`; sus solicitudes SO-00077, SO-00078 y SO-00079 tienen `Tasa_Nominal = Tasa_Efectiva = 24`. AF-0031 "Acme Corporation Inc." tiene `Taza_de_Interes = 4`.
- Las acciones de campo "Asignar Tasa Nominal 18" y "Asignar Tasa Efectiva 18" (valor fijo 18, creadas 04/05-may-2026) existen pero están **desasociadas** (`associated: false`): la tasa fija de la v0 ya no aplica. Confirma §16.2.
- Ninguna regla de workflow de CRM copia la tasa del afiliado a la solicitud; por tanto lo hace el formulario Creator (Deluge) o N8N. Se confirma con el código Deluge (§7) o con el 05 v2.

Plazo, frecuencia y cuotas:
- `Cuotas` es picklist `6` / `9` (quincenas). Las tres solicitudes observadas usan `6` (= 3 meses). No existe `12`, `18` ni `24` (ver `docs/RIESGOS.md` R14).
- `Letra_Mensual` (etiqueta real: "Letra Quincenal", currency): 28.67 para $100 al 24 % con 6 cuotas; 86.00 para $300 al 24 % con 6 cuotas. Coincide con la fórmula §4.6-a (ver §5).
- Frecuencia: `Afiliados.Frecuencia_de_Planilla` es **multiselección** con valores `Semanal`, `Quincenal 10-25`, `Quincenal 15-30`. AF-0031 y AF-0033 tienen `["Quincenal 10-25"]`.
- `Fecha_Inicio_Descuento` (date) = `2026-10-10` para solicitudes creadas el 29-sep, 30-sep y 01-oct con ciclo 10-25: coincide con la regla "próxima fecha de planilla estrictamente posterior" (§4.6-b).

## 5. Letra y redondeo

Script: `tests/inventario/letra_v1.mjs` (`node tests/inventario/letra_v1.mjs`, exit 0). Salida del 02-oct-2026:

```
SO-00077 / 11909610      cuotas= 6 cuota=28.67 (OK) total_formula=172.02 (DIF 0.02) total_interes_simple=172.00 (OK)
16860                    cuotas= 5 cuota=84.00 (OK) total_formula=420.00 (OK) total_interes_simple=420.00 (OK)
§4.6 $300 4% 3m          cuotas= 6 cuota=56.00 (OK) total_formula=336.00 (OK) total_interes_simple=336.00 (OK)
§4.6 $300 4% 6m          cuotas=12 cuota=31.00 (OK) total_formula=372.00 (OK) total_interes_simple=372.00 (OK)
§4.6 $300 4% 9m          cuotas=18 cuota=22.67 (OK) total_formula=408.06 (DIF 0.06) total_interes_simple=408.00 (OK)
§4.6 $300 4% 12m         cuotas=24 cuota=18.50 (OK) total_formula=444.00 (OK) total_interes_simple=444.00 (OK)
```

Conclusiones:
1. La **cuota** de §4.6-a (`redondear2(monto/cuotas + monto×tasa/100/2)`) reproduce exactamente las cuotas reales de CRM/LoanDisk (28.67 y 86.00) y el préstamo 16860 (84.00).
2. El **total** definido en §4.6-a como `cuota × cuotas` difiere en centavos del total real cuando la cuota no es exacta: 172.02 vs 172.00 (SO-00077/78) y 408.06 vs 408.00 (tabla §4.6). El total real de LoanDisk es `capital + monto × tasa × meses` (interés flat), y LoanDisk reparte la diferencia dentro de su calendario (por confirmar en el cronograma del préstamo 11909610 si la última cuota absorbe los centavos: 5 × 28.67 + 28.65 = 172.00).
3. **Regla vinculante para el Brief 06** (Gianclaudio, 02-oct-2026): la fuente de verdad del total y del calendario es el calendario que devuelve LoanDisk. `/api/quote` muestra cuota y total estimados; al crear el préstamo, `mp_loandisk_crear` guarda el calendario de LoanDisk en `evaluaciones.snapshot` y los documentos y el estado de cuenta se generan desde ese snapshot. No se recalcula por fórmula. Pendiente Brief 06: leer el cronograma real del 11909610 y fijar en el test cómo se reparten los centavos.

## 6. Zoho CRM

Módulos: `Afiliados` (id `6982798000002954562`), `Solicitudes_Microprestamo` (id `6982798000002953002`). Metadata completa en los resultados de `getFields` (78 y 90 campos); abajo los campos que la app usa.

### 6.1 `Afiliados` — campos relevantes

| API name | Etiqueta | Tipo | Valores / notas |
|---|---|---|---|
| `ID_Afiliado` | ID Afiliado | autonumber | Formato observado `AF-0033`; el registro antiguo tiene `AF -0031` (prefijo con espacio). Normalizar al espejar. |
| `Name` | Nombre Empresa | text | |
| `Nombre_Comercial` | Nombre Comercial | text | |
| `Estado` | Estado | picklist | `Activo`, `Inactivo`, `Suspendido`. **Vacío** en los dos afiliados. |
| `Estado_del_Contrato` | Estado del Contrato | picklist | `Pendiente`, `Enviado a firma`, `Firmado Afiliado`, `Firmado Completo`. Ambos afiliados: `Enviado a firma`. §16.4: el convenio se firma en físico; la app marcará `Firmado`. |
| `Taza_de_Interes` | Taza de Interes | percent | Fuente única de la tasa (§4.4). AF-0033 = 24, AF-0031 = 4 |
| `Tasa_de_Comisi_n` | Tasa de Comisión | percent | AF-0033 = 4 |
| `Frecuencia_de_Planilla` | Frecuencia de Planilla | multiselectpicklist | `Semanal`, `Quincenal 10-25`, `Quincenal 15-30` |
| `LoanDisk_Branch_ID` | LoanDisk Branch ID | text | 92588 / 91008 |
| `L_mite_para_nuevos_descuentos` | Límite para nuevos descuentos | text | AF-0033 = "6" (semántica por confirmar con Diego) |
| `Fecha_de_corte_de_planilla` | Fecha de corte de planilla | text | AF-0033 = "6" (idem) |
| `WorkDrive_Folder_ID`, `WD_Base_Diaria_ID`, `WD_Contrato_ID`, `WD_Solicitudes_ID`, `WD_Base_Diaria_Link`, `Carpeta_WorkDrive` | carpetas WorkDrive | text / website | Escritos por Zoho Flow "Crear Carpetas Afiliados". AF-0033: folder `nsneue1dd76443451480491f5eac22c2f751f`, Base Diaria `nsneu9717f6d9917a446ab38923565f6682e6`, Contrato `nsneub644c338e4824c2ab2a571b3c3fd3be7`, Solicitudes `nsneu2f7d56633fea48d5bc25901844a35361` |
| `Fecha_Ultima_Carga_Base`, `Base_Empleados_Actualizada` | carga de base | datetime / picklist Si-No | Vacíos |
| `Nombre_RRHH`, `Email_RRHH`, `Tel_fono_RRHH`, `Nombre_Finanzas`, `Email_Finanzas`, `Tel_fono_Finanzas` | contactos | text/email/phone | Fuente de `usuarios_afiliado` (magic link) |
| `Nombre_Contacto_Corporativo`, `Email_Corporativo`, `Tel_fono_Corporativo`, `C_dula_Rep_Legal`, `Cargo_Rep_Legal`, `Nacionalidad_del_Rep_Legal` | representante legal | | Convenio |
| `RUC` (etiqueta "Folio"), `No_de_Aviso_de_Operaci_n`, `Aviso_de_Operaci_n`, `Cert_Registro_P_blico`, `Copia_C_dula_Rep_Legal`, `Certificaci_n_bancaria_constancia_de_cuenta` | documentos de alta | text / fileupload | Zoho Forms "Formulario de Afiliación Empresarial" |
| `Cuenta_Bancaria_Comision`, `Banco`, `Tipo_de_cuenta`, `Beneficiario_titular_de_la_cuenta` | cuenta para comisión | text | Liquidación mensual 4 % |
| `ID_Zoho_Sign_Document_ID`, `Fecha_Env_o_Contrato`, `Fecha_Firma_Interna`, `Fecha_Firma_Afiliado` | firma del convenio (v0) | | Ya no aplica: convenio en físico |
| `Loan_Product`, `Number_of_Payments`, `Repayment_Cycle` | LoanDisk | text | Vacíos; no son fuente |
| **No existe** `Modo_Validacion` | | | Debe crearse en el Brief 05 (cambio en CRM con aprobación) |

Afiliados existentes (COQL, `ID_Afiliado is not null`): 2 registros, ambos de prueba: `AF -0031` Acme Corporation Inc. (18-may-2026, branch 91008, tasa 4) y `AF-0033` Prueba Inc. (29-sep-2026, branch 92588, tasa 24, comisión 4, ciclo 10-25). El afiliado real del piloto se definirá al momento de la prueba (§4.3-bis).

### 6.2 `Solicitudes_Microprestamo` — campos relevantes

| API name | Etiqueta | Tipo | Valores / notas |
|---|---|---|---|
| `ID_Solicitante` | ID Solicitante | autonumber | Formato observado **`SO -00079`** (prefijo `SO -` con espacio). La app debe normalizar a `SO-00079` al mostrar y buscar. |
| `Name` | Solicitud Microprestamo Name | text | No es el número SO |
| `Estado_Solicitud` | Estado Solicitud | picklist | Metadata: `En Revision`, `Pendiente Firma`, `Rechazada`, `Pendiente Desembolso`, `Desembolsada`, `Aprobada`, `Nueva`, `Pendiente KYC`, `Recibida`, `Validando Empresa`. **Observado además:** `Cancelada` (SO-00077). |
| `Canal_de_Entrada` | Canal de Entrada | picklist | Metadata: `Zoho Form`. **Observado:** `Formulario Web (Creator)`. |
| `Monto_Solicitado` | Monto Solicitado | picklist | `100`, `150`, `200`, `300` |
| `Cuotas` | Cuotas | picklist | `6`, `9` |
| `Letra_Mensual` | **Letra Quincenal** | currency | 28.67 / 86.00 |
| `Tasa_Nominal`, `Tasa_Efectiva` | | percent | 24 / 24 (misma cifra, §4.6-a) |
| `Fecha_de_Solicitud` | | datetime | = `Created_Time` ± 1 s |
| `Fecha_Inicio_Descuento` | | date | 2026-10-10 en los tres casos |
| `Salario_Mensual` | | currency | Declarado por el solicitante |
| `ID_Afiliado` | | text | `AF-0033` (no es lookup) |
| `LoanDisk_Branch_ID` | | text | heredado del afiliado |
| `Prestamo_No` | Prestamo No. | bigint | número de préstamo LoanDisk |
| `Aprobaciones_BG` | **Codigo Pago** | integer | código BG |
| `Referencia_de_Transferencia` | **Confirmacion** | text | referencia BG |
| `Banco_Desembolso`, `Tipo_de_Cuenta`, `Es_Titular_de_la_Cuenta`, `Numero_de_Cuenta`, `Titular_Cuenta_Completo` | cuenta destino | | ver §2 |
| `Sign_Request_ID_Contrato`, `Sign_Request_ID_Pagare`, `Sign_Request_ID_Carta`, `Sign_Request_ID_APC` | | text | Sobre único: el **mismo** `request_id` en los 4 (SO-00078 `561993000000350144`, SO-00079 `561993000000360046`). SO-00077 (antes del sobre único) tenía IDs distintos por documento. |
| `Sign_Status_Contrato`, `_Pagare`, `_Carta`, `_APC` | | picklist | `IN PROGRESS`, `COMPLETED`, `ERROR`, `RECALLED` |
| `Sign_Detalle_*` | | text | detalle del evento |
| `Folder_ID_KYC`, `Folder_ID_Formulario`, `Folder_ID_Documentos_Firmados`, `Folder_ID_Aprobacion_Gerencia`, `Folder_ID_RRHH`, `Folder_ID_Solicitante`, `Folder_ID_Desembolso` | carpetas WorkDrive | text | 7 carpetas por solicitud (Zoho Flow "Crear Carpetas Microprestamo"). La app usa `01_KYC … 06_Desembolso` (§4.1); mapear 7→6 en el Brief 08. |
| `WorkDrive_KYC_URL`, `_Formulario_URL`, `_Docs_Firmados_URL`, `_Aprobacion_URL`, `_RRHH_URL`, `_Solicitante_URL`, `_Desembolso_URL` | | website | enlaces de las mismas carpetas |
| `IDAnalyzer_Session_ID`, `IDAnalyzer_Transaction_ID` | KYC | text | |
| `Acepta_Terminos`, `Single_Line_24` ("Date & Time"), `Single_Line_25` ("IP Address"), `Firma`, `Firma_Img` | evidencia de consentimiento v1 | | La app reemplaza por `consentimientos` (§6) |
| `Submission_ID`, `ID_Externo_Formulario`, `Codigo_de_Empleado`, `Lugar_de_Trabajo`, `Sucursal_de_Trabajo` (picklist de provincias), `Cargo`, `Paga_Servicios_Publico`, `Nacionalidad`, `Ref_Nombre_Completo`, `Ref_Telefono`, dirección (`Provincia`, `Ciudad`, `Corregimiento`, `Direccion_Calle`, `Casa_o_Apartamento`) | datos del formulario | | Modelo del wizard |
| `Observaciones_Operaciones` | | textarea | notas del analista |

Registros de referencia (COQL, `Created_Time > 15-sep-2026`; PII omitida):

| SO | Creada | Estado | Monto | Cuotas | Letra | Tasa | Inicio desc. | Afiliado / branch | Préstamo LD | Sign request | Sign status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| SO-00077 | 29-sep 16:04 | Cancelada | 100 | 6 | 28.67 | 24 | 2026-10-10 | AF-0033 / 92588 | — | APC `…350060`, Carta `…350011` (separados) | Carta RECALLED, resto IN PROGRESS |
| SO-00078 | 30-sep 12:38 | Pendiente Desembolso | 100 | 6 | 28.67 | 24 | 2026-10-10 | AF-0033 / 92588 | 11909610 | `561993000000350144` ×4 | COMPLETED ×4 |
| SO-00079 | 01-oct 10:43 | Pendiente Desembolso | 300 | 6 | 86.00 | 24 | 2026-10-10 | AF-0033 / 92588 | 11913796 | `561993000000360046` ×4 | COMPLETED ×4 |

### 6.3 Reglas de workflow (`getWorkflowRules`)

`Solicitudes_Microprestamo` (5 reglas activas, en orden de ejecución):

| Regla | ID | Disparador | Acción conocida | Última ejecución |
|---|---|---|---|---|
| MP - SOL- NUEVA → EN REVISIÓN | `6982798000002964345` | create | Field update "Actualizar Estado de Solicitud" → `En Revision` | 19-jun-2026 |
| Calcular Fecha Inicio Descuento | `6982798000004148028` | create_or_edit (sin repetición) | Función Deluge (nombre no expuesto por la API). Descripción: "Fecha Documental para Carta de descuento directo". **Modificada el 29-sep-2026 11:38** (regla de la quincena, §17.1) | 01-oct-2026 11:03 |
| Solicitudes_Microprestamo_ZohoFlow_Crear Carpetas | `6982798000005439001` | create | Webhook a Zoho Flow (crea las 7 carpetas WorkDrive) | 01-oct-2026 10:43 |
| MP - Enviar Documentos a Firma | `6982798000005442059` | field_update sobre `Estado_Solicitud` (cualquier valor; descripción: cuando pasa a `Pendiente Firma`) | Función Deluge `mp_enviar_a_zoho_sign1` (§18) | 01-oct-2026 10:48 |
| LoanDisk_BranchID | `6982798000008898010` | create | Hereda `LoanDisk_Branch_ID` del afiliado | 01-oct-2026 10:43 |

`Afiliados` (1 regla): `Afiliados_ZohoFlow_Crear Carpetas Afiliados` (`6982798000004398001`, create, webhook a Zoho Flow; última ejecución 29-sep-2026 12:45). §4.3: este disparador pasa a N8N sobre el cambio de `Taza_de_Interes`.

Field updates existentes: "Actualizar Estado de Solicitud" (→ `En Revision`, asociado); "Asignar Tasa Nominal 18" y "Asignar Tasa Efectiva 18" (valor fijo 18, **no asociados**).

Webhooks: los dos de Zoho Flow (uno por módulo), `POST` a `flow.zoho.com/901020361/...` con una clave `zapikey` en la URL (**no se copia**; ver `docs/RIESGOS.md` R18). Se retiran con Zoho Flow (Briefs 08 y 19).

## 7. Deluge

| Función | Dónde se dispara | Qué hace (observado) | Código fuente |
|---|---|---|---|
| `mp_enviar_a_zoho_sign1` | Regla "MP - Enviar Documentos a Firma" (CRM) | Con la conexión `zoho_sign` une los 4 templates en un sobre único (`templates/mergeview` + `templates/mergesend`), envía al solicitante con el nombre y guarda el mismo `request_id` en los 4 campos `Sign_Request_ID_*` (§18; confirmado en SO-00078/79). Pendiente ver cómo llena los campos de merge (§8) y el orden RRHH. | **Pendiente**: Gianclaudio pegará el código. |
| Función de "Calcular Fecha Inicio Descuento" | Regla CRM create_or_edit | Escribe `Fecha_Inicio_Descuento` = próxima fecha de planilla estrictamente posterior según `Frecuencia_de_Planilla` del afiliado (resultado 2026-10-10 para 29-sep/30-sep/01-oct con 10-25). Se replica con la regla §4.6-b y sus tests (Brief 06). | Pendiente (no expuesto por API; opcional, la regla ya está formalizada en §4.6-b). |
| `procesarCSVEnCreator` | Zoho Flow / Creator | Upsert de la Base Diaria en Creator `Empleados` | **No se documenta**: Creator se retira (decisión 02-oct-2026). |
| Copia de la tasa afiliado → solicitud | Formulario Creator o N8N | Ver §4 | Pendiente (se resuelve con `mp_enviar_a_zoho_sign1` o con el 05 v2). |

## 8. Zoho Sign — templates

Propietario `glopolito@isthmuscap.com`; todos secuenciales, expiración 15 días, recordatorio cada 5 días, visibilidad `MustSignToView`, idioma `es`, país `PA`, entrega por email.

| Template | ID | Document ID | Firmantes (orden · rol · tipo) | Campos de merge (`field_label`) |
|---|---|---|---|---|
| MP - Contrato de Préstamo | `561993000000057083` | `561993000000346064` | 1 · `Solicitante` · SIGN (campo Signature p.0) · 2 · `Isthmus` · **APPROVER** (Gisela) | `numero_prestamo`, `fecha`, `nombre_completo` ×2, `ciudad`, `cedula` ×2, `monto_prestamo` ×2, `Tasa_Nominal`, `Tasa_Efectiva`, `plazo` ×2, `monto_total`, `cuota_mensual`, `empresa`, `fecha_dia`, `fecha_anio`, `fecha_mes` |
| MP - Pagaré | `561993000000058038` | `561993000000346040` | 1 · `Solicitante` · SIGN | `fecha` ×2, `monto_prestamo` ×2, `nombre_completo` ×2, `cedula` ×2, `cuota_mensual`, `Tasa_Nominal` |
| MP - Carta de Descuento Directo | `561993000000058099` | `561993000000346051` | 1 · `Solicitante` · SIGN · 2 · `Isthmus` · **APPROVER** (Gisela) · 3 · `RRHH_Afiliado` · SIGN | `fecha_dia`, `fecha_mes`, `fecha_anio`, `nombre_completo` ×2, `cedula` ×2, `cuota_mensual`, `cuota_letras`, `fecha_primer_pago`, `plazo`, `monto_letras`, `monto_prestamo` |
| MP - Autorización APC | `561993000000058138` | `561993000000346023` | 1 · `Solicitante` · SIGN | `fecha`, `nombre_completo`, `nacionalidad`, `cedula` ×2, `email`, `celular`, `telefono` |

Notas:
- Los nombres de campo (`field_name`) están vacíos; el merge usa `field_label`. Un mismo label repetido (p. ej. `cedula` ×2) se rellena con el mismo valor.
- `cuota_mensual` en los documentos es en realidad la **cuota quincenal** (coincide con `Letra_Mensual` = "Letra Quincenal" en CRM). Revisar el texto legal en el Brief 10.
- **Discrepancia con §13.2:** Contrato y Carta conservan un paso `APPROVER` de Isthmus (Gisela) y la Carta tiene 3 pasos. Ver `docs/RIESGOS.md` R13; se decide en el Brief 10.
- Para la app (`mp_sign_enviar`): necesita por documento los valores de arriba más `numero_prestamo` (no existe antes de crear el préstamo en LoanDisk: hoy el orden es Sign → LoanDisk, por lo que hay que confirmar qué se pone en `numero_prestamo`; probablemente el `SO`).

## 9. Monday (solo lectura, durante la migración del flujo BG)

Tableros localizados con `search`:

| Tablero | ID | Workspace | Notas |
|---|---|---|---|
| MicroPago Aplicacion (plantilla) | `9281523816` | 11192565 "Producto B - Plantilla" | 0 ítems; creado por Diego González (Simplifica.biz). Columnas: nombre, apellido, cédula, teléfono, fecha de aplicación, banco (dropdown: Banco General, BAC, Caja de Ahorros, Banco Nacional, Otro, Global Bank, Banistmo), cuenta de depósito (numbers), fotos (cédula, ficha CSS, selfie), espejos de documentos firmados desde el tablero `8478471349`, `Documentos Requeridos` (status 0–7), `Status de Solicitud` (En Revision / Aprobado / Denegado / Cancelado), `Monto del Prestamo` (status 100/150/200/250/300) + `Monto del Prestamo Num`, fórmulas `Letra Quincenal` y `Letra Mensual` (valores fijos por monto, v0), `Fecha de Inicio`, `Fecha Firma CAD`, `Numero de Empleado`, `Estado de Desembolso` (espejo), `Autorización Datos Personales`, `Condicion Laboral` (Activo/Cesante), `Fecha Cesante`. Grupos: "MicroPago Aplicaciones Recibidas", "MicroPago Prestamos Aprobados". |
| Subelementos de MicroPago Aplicacion Seguridad Unida | `9321047000` | 12061442 | Subítems del tablero vivo de Seguridad Unida (ID del tablero padre pendiente) |
| SANDBOX - MicroPago / SANDBOX de MicroPago Aplicacion Seguridad Unida | `18402155250` / `18400980712` | 14394702 | Probable origen de las pruebas del 06 QA |
| Saldos de Clientes Seguridad Unida, Letras, Contabilidad SU | `18304142131`, `9321046317`, `18131566116` | 12061442 | Cobro v0 (fuera del alcance de la app hasta su migración) |

Las fórmulas de Monday (`Letra Quincenal` 27.53/55.06/282.59 y `Letra Mensual` 55.06/110.13/165.19 por monto) son de la v0 y **no** coinciden con §4.6; no se replican. La relación exacta tablero → 06 prod (qué columnas forman el payload BG) queda pendiente de la sección 1.

## 10. Supabase

- Organización: `Isthmus Capital` (`dsokfwbgooixlpjflflv`).
- Proyectos existentes: `isthmus-cotizador` (`aezbofbjcuwjwoanmscx`, us-east-1, PG 17) y `maxmotors-precios` (`ktdycqrkhccpycrsoszb`, us-east-1, PG 17).
- **`isthmus-mp` no existe.** Pendiente upgrade a Pro antes de crearlo (Brief 03). Ver `docs/RIESGOS.md` R10.

## 11. Accesos

| Acceso | Estado 02-oct-2026 | Evidencia |
|---|---|---|
| SSH al VPS desde VS Code | OK | Esta sesión corre en `isthmus-n8n` (`5.78.214.136`) como `root`; Brief 01 crea `deploy`. Contenedores activos: `cotizador-app` :3001, `maxmotors-app` :3002, `n8n-n8n-1` :5678, `n8n-postgres-1`, `gotenberg` :3000. Node 22.22.1, npm 9.2.0, Docker 29.7.2, Caddy, Python 3.14. |
| DNS `mp.isthmuscap.com` | **Sin registro A** | `dig +short` vacío. Idem `staging-mp.` y `microprestamos.`. `automation.isthmuscap.com` → 5.78.214.136. Crear en el Brief 01. |
| Supabase `isthmus-mp` | **Pendiente** (upgrade Pro) | §10 |
| Token WhatsApp en `.env` | OK | `.env` con permisos 600 (root); 5 claves `WHATSAPP_*`; `WHATSAPP_PHONE_NUMBER_ID = 1184886231372996`, `WHATSAPP_BUSINESS_ACCOUNT_ID = 4466216373701343`, `WHATSAPP_APP_ID = 1360854289567229`, `WHATSAPP_TEMPLATE_OTP = fic_mp_codigo_acceso` (coinciden con §14); `WHATSAPP_TOKEN` presente (194 caracteres, no se imprime). Pendiente Brief 04: validar con el Access Token Debugger y planificar rotación. |
| Credencial N8N `Meta WhatsApp MP` | **Sin confirmar** | Bloqueo del MCP n8n (sección 0). Gianclaudio la crea o confirma. |
| Playwright en el VPS | **No soportado nativo** | Playwright 1.56 no soporta Ubuntu 26.04 (`npx playwright install chromium` falla) y el MCP de Playwright no encuentra Chrome. Brief 02: correr Playwright en Docker (`mcr.microsoft.com/playwright`). Las capturas del Brief 00 se hicieron con Gotenberg (`gotenberg/gotenberg:8`, v8.34.0, contenedor existente). |
| Remoto git | **No hay** | `git remote -v` vacío; MCP GitHub falló al conectar. Ver R11. |
| Diseño: 5 pantallas en Claude Design | **No existen** | `Artifact list` sin artefactos de tipo Design; ver `docs/design/README.md`. |

## 12. Pendientes y bloqueantes

**Bloqueantes**
1. **MCP n8n re-autenticado** (Gianclaudio, en claude.ai → conectores). Sin esto no hay payload BG ni IDs LoanDisk "tal como viajan" (secciones 1–3). Alternativa: autorizar explícitamente una lectura `SELECT` de solo lectura sobre la BD de n8n.
2. **Supabase Pro** antes del Brief 03.
3. **Remoto git** o backup off-site antes del Brief 01.

**Pendientes (no bloquean el Brief 01/02)**
4. Código Deluge de `mp_enviar_a_zoho_sign1` (Gianclaudio lo pega).
5. Confirmar `loan_disbursed_by_id`, `loan_payment_scheme_id` por ciclo y fees (cierre, timbres, seguro) en el 05 v2.
6. Gisela: habilitar el esquema 15-30 (4418) en el producto 383523; confirmar cómo LoanDisk reparte los centavos en el cronograma del 11909610.
7. Diego: decidir si se elimina el paso APPROVER de Gisela en los templates Contrato y Carta (R13); semántica de `L_mite_para_nuevos_descuentos` y `Fecha_de_corte_de_planilla`.
8. Crear `Modo_Validacion` en CRM `Afiliados` y ampliar picklists `Cuotas`/`Monto_Solicitado` (Brief 05, cambios en CRM con aprobación).
9. Crear DNS `mp.` y `staging-mp.` (Brief 01).
10. Credencial N8N `Meta WhatsApp MP`: confirmar o crear.
11. Diseñar y aprobar las 5 pantallas con Diego antes del Brief 02.
12. Brief 02: Playwright en Docker (no hay soporte nativo de Chromium en Ubuntu 26.04).
13. Validar en vivo el 03 KYC corregido (publicado el 02-oct-2026) con el próximo KYC real; anotar el resultado aquí.
14. Diego: aprobar en Banca en Línea la transferencia BG código 18524 de SO-00079 y confirmar que el 07 la refleja en CRM (`Desembolsada`).
