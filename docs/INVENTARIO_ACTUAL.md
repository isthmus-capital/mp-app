# Inventario del proceso actual (v1 Zoho + N8N) — Brief 00
<!-- Paquete: v5 — Brief 00 — 02-oct-2026 -->

**Fecha:** 02-oct-2026. **Alcance:** lo que hoy mueve una solicitud de micropréstamo desde el formulario Creator hasta el desembolso BG, con los nombres reales (API names, IDs, picklists) que la app debe replicar. **Modo:** solo lectura; ningún workflow, registro ni configuración fue modificado.
**Enmascarado:** no se copian cédulas, cuentas, teléfonos, correos de solicitantes, salarios ni IDs de sesión KYC. Los IDs de registros, templates, carpetas y préstamos sí se documentan porque la app los necesita.
**Herramientas usadas (solo lectura):** Zoho CRM MCP (`getFields`, `getWorkflowRules`, `getWebhooks`, `getFieldUpdates`, COQL), Zoho Sign MCP (`getTemplateDetails`), Supabase MCP (`list_organizations`, `list_projects`), Monday MCP (`search`, `get_board_info`), Claude Docs (lectura de "LoanDisk FECI Configuration Guide" y "Proceso de Micropréstamos"), shell local (`dig`, `stat`, `grep`, `node`).

## 0. Estado del inventario

| Sección | Estado | Fuente |
|---|---|---|
| 1. Workflows N8N | **Completo** (03, 04, 05 v2, 06 QA/prod, credenciales; subagentes de solo lectura tras la re-autenticación del conector, 02-oct-2026). El 03 publicado difiere del comportamiento descrito: ver 1.2 | El MCP de n8n pide re-autenticación (OAuth, no posible en sesión no interactiva). La lectura directa de la base de n8n fue denegada por el clasificador de permisos de Claude Code. Lo que figura abajo viene de §2, §8 y §18 del Prompt Maestro y debe confirmarse contra los nodos reales. |
| 2. Payload BG | Completo | Sección 1.5: contrato de entrada del 06 y los 12 campos del body BG |
| 3. IDs LoanDisk | Completo (calendario no visible) | Sección 1.4: payload loan/borrower tal como viaja en el 05 v2; el cronograma no queda en N8N |
| 4. Tasa | Completo | CRM `Tasa_Nominal` → `Number().toFixed(4)` → `loan_interest` flat_rate Month (1.4) |
| 5. Letra y redondeo | Completo | `tests/inventario/letra_v1.mjs` |
| 6. Zoho CRM | Completo | `getFields` + reglas + registros reales |
| 7. Deluge | Parcial | Reglas y comportamiento observado; código fuente pendiente (Gianclaudio pegará `mp_enviar_a_zoho_sign1`). |
| 8. Zoho Sign | Completo | 4 templates leídos |
| 9. Monday | Completo | El 06 prod no tiene nodos Monday: es un webhook compartido; Seguridad Unida lo llama desde `5wHL8Ut1ZT8SUZ2B` |
| 10. Supabase | Completo | Proyecto `isthmus-mp` no existe |
| 11. Accesos | Completo | Ver §11 |

### 0.1 Cambios v1 — bitácora de cambios en los workflows de la v1 durante el proyecto

| Fecha (UTC) | Workflow | Versión activa | Cambio | Quién | Validación |
|---|---|---|---|---|---|
| 2026-10-01 16:16 | 03 KYC `n4uerlMucRTnR8Bu` | `cb696e63-3091-4143-a034-388b718b9269` | Versión "corregida" (WhatsApp independiente de la solicitud, búsqueda con reintentos, correo a los 30 min, 3 reportes a KYC). La lectura por MCP del 02-oct detectó las salidas false de los dos IF sin conectar (1.2). | Gianclaudio, manual en N8N | Sin ejecuciones |
| 2026-10-02 02:19 (21:19 Panamá) | 03 KYC `n4uerlMucRTnR8Bu` | **`37e44e08-3809-4a65-817d-a0c2fede1893`** | **Recableadas solo las salidas false** de "IF - Solicitud Encontrada" (→ "IF - Seguir Esperando") y de "IF - Seguir Esperando" (→ "Aviso - KYC sin Solicitud"). Verificado por MCP (`get_workflow_details`, solo lectura): ahora reintenta cada 2 min hasta 15 veces cuando no hay solicitud, avisa a los 30 min, y con solicitud procesa una sola vez. Sin otros cambios. | Gianclaudio, manual en N8N | **Pendiente validación en vivo** (próximo KYC real) |

Residuales del 03 tras el recableado (ver 1.2): el WhatsApp sigue colgando de la misma salida que la búsqueda y, por `executionOrder v1` y su posición en el canvas, se ejecuta **después** de la rama de búsqueda; en el caso normal (KYC antes de la solicitud) saldría al terminar el bucle, hasta 30 min después. `transaction_id` sigue leyendo `body.id` (null). Token de Meta en el nodo. Rama de rechazo sin envío. **Precisión 02-oct-2026 (Gianclaudio): IDAnalyzer redirige al formulario al aprobar; el WhatsApp con el enlace es un respaldo, no el camino principal. Este residual queda en prioridad Baja (R34).**

## 1. Workflows N8N — inventario de nodos (02-oct-2026, solo lectura por MCP)

**Método.** Conector n8n re-autenticado por Gianclaudio; tres subagentes de solo lectura con `search_workflows`, `get_workflow_details`, `list_credentials`, `search_workflow_executions` y `get_workflow_execution`. Nada se ejecutó, modificó ni publicó. Valores de headers, tokens y claves redactados; PII enmascarada. Lo que n8n no guarda (p. ej. el body exacto enviado por un nodo HTTP) se reconstruyó a partir de las expresiones y de los nodos previos, y se marca como "reconstruido".

### 1.1 Resumen

| Workflow | ID | Nombre real en N8N | Activo | activeVersionId | Actualizado (UTC) | Trigger |
|---|---|---|---|---|---|---|
| 03 KYC | `n4uerlMucRTnR8Bu` | "03 - MP KYC - Callback IDAnalyzer" | sí | `37e44e08-3809-4a65-817d-a0c2fede1893` (republicado 02-oct 02:19 UTC; antes `cb696e63…`) | 2026-10-02 02:19 | Webhook POST `/webhook/mp-kyc-callback`, sin autenticación (callback DocuPass) |
| 04 Sign events | `HeXyYSjeUXu5qTBi` | "04 - ZOHO - Documentos Firmados" | sí | `99c57751-efb4-4a2b-b7a6-c10c72af1905` | 2026-09-30 22:52 | Webhook POST `/webhook/mp-sign-docs`, sin autenticación (Zoho Sign) |
| 05 v2 LoanDisk + BG | `iPM3haUtdcof745M` | "05 v2 - MP Zoho → LoanDisk (BORRADOR)" | sí | `9899f185-c551-4c9a-8408-c95bc82a7fa5` | 2026-10-01 15:18 | Webhook POST `/webhook/mp-carta-firmada-v2`, **sin autenticación** |
| 06 QA | `EQOqUBQp1N60zFlG` | "06 QA - BG Crear Transferencia (certificacion, sin dinero)" | sí | `ce250e87-e128-49aa-8ec9-cdd97684dc04` | 2026-10-01 15:12 | Webhook POST `/webhook/bg-crear-transferencia-qa`, sin autenticación |
| 06 prod | `GTFFlEfXa0LOTtnF` | "06 - BG - Crear Transferencia" | sí | `ad844122-84fb-4c09-b2eb-c76c2ce2ed2c` | 2026-10-01 16:04 | Webhook POST `/webhook/bg-crear-transferencia`, **sin autenticación** |
| "Flujo vigente" citado en el Brief 00 | `5wHL8Ut1ZT8SUZ2B` | "Monday → LoanDisk \| Aprobado" | sí | — | 2026-09-04 | Webhook de Monday (board 224465445). **No es el flujo MP**: es el flujo anterior Monday/Jotform (producto 365871, `interest_only` 16 % fijo, 24 cuotas, branch fijo 87572, llama al 06 prod sin condición de ambiente). Los IDs MP viven en el nodo "Config MP" del 05 v2. |
| 07 polling | — | **No existe**: ningún nodo del 05 v2 ni de los 06 referencia un workflow de seguimiento. El estado final de la transferencia no se consulta. | | | | |

Todos los workflows MP están en la carpeta `FbzPrZ0TGC7IFJxr`, sin tags. El 05 v2 se llama "(BORRADOR)" pero está activo y apunta a producción.

### 1.2 03 KYC — Callback IDAnalyzer (`n4uerlMucRTnR8Bu`)

**Identidad.** "03 - MP KYC - Callback IDAnalyzer", activo, versionId = activeVersionId **`37e44e08-3809-4a65-817d-a0c2fede1893`** (borrador = publicado), **republicado 2026-10-02 02:19 UTC** (21:19 Panamá) por Gianclaudio con el recableado de las salidas false de los dos IF (bitácora 0.1); la versión anterior `cb696e63…` (01-oct 16:16 UTC) tenía esas salidas sin conectar. 19 nodos (uno deshabilitado), creado con el AI builder, sin errorWorkflow. **La versión publicada no tiene ejecuciones todavía**; las 21 ejecuciones existentes son anteriores (29561–29585 del 01-oct).

**Trigger.** Webhook POST `/webhook/mp-kyc-callback`, responde de inmediato, **sin autenticación ni validación de firma**. Payload DocuPass en `body`: `decision`, `event`, `customData` (formato `cedula|telefono`), `docupass` (session), `transactionId`, `profileId`, `success`, `data`, `outputImage{front,back,face}` (tokens de filevault), `outputFile[]{name,fileName,fileUrl}` (3 PDF: Transaction Audit Report, Face Audit Report, Docupass Audit Report, en `api2-us2.idanalyzer.com/filevault/…`, descargables **sin autenticación**).

**Nodos.** "Extraer Campos" (Set: decision, cédula y teléfono desde `customData`, docupass, event, imágenes; `transaction_id = body.id` — **campo equivocado**, el payload trae `transactionId`, por lo que queda `null`) → "decision == accept?" (`decision == accept` AND `event == docupass_conclusive`) → rama aprobado: "Preparar Mensaje Aprobado" (Set; su texto apunta a microprestamos.isthmuscap.com y **ningún nodo lo usa**) → en paralelo (a) "HTTP -WhatsApp - Enviar Formulario" (POST `graph.facebook.com/v19.0/<phone_number_id>/messages`, `type: text` con enlace **http**://solicitudmp.isthmuscap.com/; `onError: continueRegularOutput`; **token de Meta escrito en el nodo**, sin credencial) y (b) "HTTP - Buscar Solicitud CRM" (GET `/crm/v7/Solicitudes_Microprestamo/search?criteria=(C_dula_ID:equals:<cedula>)&fields=id,Folder_ID_KYC`, **neverError: true**, credencial `V8ToVmg60xSjZasl`) → "IF - Solicitud Encontrada" → "HTTP - Actualizar Session ID CRM" (PUT crm/v2: `IDAnalyzer_Session_ID`, `IDAnalyzer_Transaction_ID`) → "Edit Fields" / "Split - outputFile" → "HTTP - Descargar PDF IDAnalyzer" → "HTTP - Subir PDF WorkDrive KYC" (upload a `Folder_ID_KYC`, nombre original `…-audit-report_<rand>.pdf`, sin SO ni cédula, credencial `lRBD9utZoqJjYHEW`) → "Aggregate". Espera: "IF - Seguir Esperando" (`$runIndex < 15`) → "Wait 2 min" → vuelve a "Buscar Solicitud CRM"; "Aviso - KYC sin Solicitud" (Gmail `l3e9P4UxBqKXKir4`, a g\*\*\*@isthmuscap.com ×2, asunto "MP - KYC aprobado sin solicitud: <cedula>", cuerpo con cédula, **teléfono**, sesión y enlace a la ejecución). Rama rechazado: "Preparar Mensaje Rechazado" → "WhatsApp - Enviar Rechazo [PENDIENTE]" (marcador; **no envía nada**).

**Comportamiento previsto (Gianclaudio, 02-oct-2026) vs. nodos publicados.** Lectura inicial sobre `cb696e63…` (subagente) y re-verificación sobre `37e44e08…` tras el recableado (sesión principal, `get_workflow_details`):

| Previsto | Según los nodos publicados | Estado |
|---|---|---|
| WhatsApp con el enlace **de inmediato** al aprobar, sin depender de la solicitud; si falla no frena el resto | No depende de la solicitud y no frena (`continueRegularOutput`) ✅, pero con `executionOrder v1` el nodo se ejecuta **al final** de la rama de búsqueda (posición x=224 frente a x=-848 de "Buscar Solicitud CRM"; en 29585 fue el último nodo, índice 11). **Sin cambios en `37e44e08`**: en el caso normal (KYC antes de la solicitud) el bucle corre primero y el WhatsApp saldría hasta 30 min después | **Sigue abierto** |
| Busca por cédula; si no existe, reintenta cada 2 min hasta 15 veces | En `cb696e63…` la salida false no estaba conectada. **Corregido en `37e44e08…`**: false → "IF - Seguir Esperando" → "Wait 2 min" → nueva búsqueda, hasta `$runIndex < 15` | **Corregido, pendiente validación en vivo** |
| A los 30 min sin solicitud, correo desde gestionprestamos@ a Gisela y Gianclaudio | En `cb696e63…` el aviso colgaba de la salida true (correos falsos). **Corregido en `37e44e08…`**: false de "IF - Seguir Esperando" → "Aviso - KYC sin Solicitud" (credencial `l3e9P4UxBqKXKir4`, a ggonzalez@ y glopolito@) | **Corregido, pendiente validación en vivo** |
| Si la encuentra: `IDAnalyzer_Session_ID` en CRM y 3 reportes al folder KYC | Confirmado ✅; con `37e44e08…` se procesa **una sola vez** (true → Actualizar Session ID → Split → Descargar → Subir → Aggregate, sin volver al bucle). Residual: `IDAnalyzer_Transaction_ID` queda `null` (`body.id` vs `transactionId`, asignación duplicada) | **Corregido el bucle; `transaction_id` sigue null** |

Conexiones verificadas en `37e44e08…`: `IF - Solicitud Encontrada.main[0]` → Actualizar Session ID; `main[1]` → IF - Seguir Esperando; `IF - Seguir Esperando.main[0]` → Wait 2 min; `main[1]` → Aviso. **Residual (prioridad Baja desde el 02-oct-2026: IDAnalyzer redirige al formulario al aprobar; el WhatsApp es respaldo):** mover el WhatsApp antes de la búsqueda (p. ej. Preparar Mensaje Aprobado → WhatsApp → Buscar Solicitud CRM) para que salga de inmediato; corregir `transaction_id` a `body.transactionId`; mover el token de Meta a una credencial. Lección confirmada: el Retry de N8N (29583/29584) reutilizó la salida guardada y volvió a fallar; para reprocesar hay que re-ejecutar con el payload original.

**Otros puntos.** Las ejecuciones con error del 01-oct (29562, 29584) fallaron en la subida a WorkDrive (400 F6003 "Invalid Param": `parent_id` con `.item`; la versión actual usa `.last()`). `redaction.production = false`: las ejecuciones guardan cédula, teléfono, email y los tokens de filevault de IDAnalyzer. El `profileId` llega en el payload y no está escrito en el 03 (vive en el 02, no revisado).

### 1.3 04 — Documentos firmados (`HeXyYSjeUXu5qTBi`)

**Identidad.** "04 - ZOHO - Documentos Firmados", activo, activeVersionId `99c57751-efb4-4a2b-b7a6-c10c72af1905`, actualizado 2026-09-30 22:52 UTC, 19 nodos, `callerPolicy: workflowsFromSameOwner`, sin errorWorkflow. 17 ejecuciones (29569–29572 el 01-oct para SO-00079).

**Trigger.** Webhook POST `/webhook/mp-sign-docs` (Zoho Sign → N8N), sin autenticación. Payload: `body.requests{request_id, request_name, request_status, document_ids[], actions[{action_type, recipient_name, recipient_email, signing_order, action_status}], …}` y `body.notifications{operation_type, activity, performed_at, ip_address}`. `request_name` observado: "MP - <nombre> - SO -00079 - Documentos del préstamo".

**Lógica.** "IF - Ignorar duplicado" descarta `operation_type = RequestSigningSuccess` con `request_status = completed` (evita el doble evento). "Verificar si esta firmado" (`completed`) → "If2 - verificar doc tipo MP" (`request_name contains "MP -"`) → **rama COMPLETED**: "WD - Refrescar token" (GET `/workdrive/api/v1/users/me`, **neverError: true**, `lRBD9utZoqJjYHEW`) → "HTTP - Buscar Registro CRM" (search por `Sign_Request_ID_Contrato OR _Pagare OR _Carta OR _APC = request_id`; con el sobre único los 4 coinciden) → "HTTP - Detalle Sign" (`sign.zoho.com/api/v1/requests/{id}`) → "Split - Documentos" (un item por `document_ids`; error si vacío) → "HTTP - Descargar PDF" (`/requests/{rid}/documents/{doc}/pdf`) → "HTTP - WD - Subir PDF" (`workdrive.zoho.com/api/v1/upload`, header `override-name-exist`, nombre **`<document_name> - <ID_Solicitante>.pdf`**, p. ej. "MP - Contrato de Préstamo - SO -00079.pdf", carpeta `Folder_ID_Documentos_Firmados`) → "Aggregate" → "HTTP - Descargar Certificate" (`/completioncertificate`) → "HTTP - WD - Subir Certificate" (**"MP - Certificado de firmas - <SO>.pdf"**, misma carpeta) → "HTTP - Actualizar Status COMPLETED" (PATCH: para cada documento cuyo `Sign_Request_ID_<Doc>` coincide, `Sign_Status_<Doc> = COMPLETED` y `Sign_Detalle_<Doc> = "Nombre: ✓ | …"`) → "HTTP - Descargar Carta" (documento cuyo nombre coincide con `/carta/i`) → "HTTP - WD - Subir a RRHH" (**"MP - Carta de Descuento Directo - <SO>.pdf"** a `Folder_ID_RRHH`) → **"Webhook - LoanDisk"**: POST a `automation.isthmuscap.com/webhook/mp-carta-firmada-v2` (el 05 v2) con `crm_id, solicitante, cedula, nombre_completo, email, id_solicitante, monto, loandisk_branch_id`, sin autenticación. **Rama IN PROGRESS** (no completado, o completado sin "MP -"): "HTTP - Buscar CRM InProgress" → "HTTP - Actualizar Status IN PROGRESS" (`Sign_Status_<Doc> = IN PROGRESS`, salvo Pagaré y APC que pasan a COMPLETED cuando el firmante de orden 1 ya firmó; también `Sign_Detalle_<Doc>`).

**Qué escribe y qué no.** Escribe solo `Sign_Status_*` y `Sign_Detalle_*`. **No escribe `Estado_Solicitud`** (queda "Pendiente Firma" hasta que el 05 v2 pone "Pendiente Desembolso") **ni `WorkDrive_Docs_Firmados_URL`** (ya existía). Lee `ID_Solicitante`, `Folder_ID_Documentos_Firmados`, `Folder_ID_RRHH`, `C_dula_ID`, `Nombre_Completo`, `Email1`, `Monto_Solicitado`, `LoanDisk_Branch_ID`. **Dispara el 05 v2 directamente por HTTP**, no por cambio de estado en CRM, siempre que se completa un sobre "MP -", sin comprobar que los 4 `Sign_Status_*` queden en COMPLETED (lo valida el 05 v2). No envía correos ni WhatsApp.

**Errores.** Sin continueOnFail, reintentos ni error workflow. Un sobre completado cuyo nombre no empiece por "MP -" cae en la rama IN PROGRESS y el PATCH fallaría con `data[0].id` indefinido. Credenciales: WorkDrive y Sign con `lRBD9utZoqJjYHEW` (como esperaba §2); CRM con `V8ToVmg60xSjZasl` (+ `lRBD` residual).

### 1.4 05 v2 — Zoho → LoanDisk → BG (`iPM3haUtdcof745M`)

**Trigger y entrada.** Webhook `mp-carta-firmada-v2` (POST, `responseMode: onReceived`, sin autenticación), llamado desde otro workflow de N8N (user-agent n8n, IP interna vía Caddy; el llamador exacto no es visible: presumiblemente el 04 al completarse las firmas). Llegan en `body`: `crm_id, solicitante, cedula, nombre_completo, email, id_solicitante, monto, loandisk_branch_id` (en una ejecución anterior también `empresa, fecha_firma_rrhh, fecha_primer_pago, telefono, banco_beneficiario, cuenta_beneficiario, tipo_cuenta`). **Solo usa `body.crm_id`**; todo lo demás lo relee del CRM (`GET /crm/v7/Solicitudes_Microprestamo/{crm_id}`, credencial `V8ToVmg60xSjZasl`).

**Nodos (21, en orden).** Trigger → "Config MP (editar aqui)" (Code, constantes) → "CRM - Leer Solicitud" → "Validar Solicitud" (Code) → IF válida → "LoanDisk - Buscar Prestamo Existente" (GET `loan/loan_application_id/{ID_Solicitante}`) → IF no existe → "LoanDisk - Crear Borrower" (POST `borrower`) → IF creado / "LoanDisk - Buscar Borrower por Cedula" (GET `borrower/borrower_unique_number/{cedula}`) → "Resolver Borrower ID" → "LoanDisk - Crear Prestamo" (POST `loan`) → IF creado → "CRM - Guardar Prestamo" (PATCH `Prestamo_No`, `Estado_Solicitud = Pendiente Desembolso`) → IF `llamar_bg` → "BG - Crear Transferencia (06)" (POST al webhook del 06) / "BG Simulado" → fin. Ramas de error → "Motivo - Prestamo No Creado" / "Armar Aviso" → "Enviar Aviso" (Gmail `l3e9P4UxBqKXKir4`, solo en fallo, a g\*\*\*@isthmuscap.com ×2, asunto "MP - Prestamo NO procesado: {nombre} ({SO})").

**Validaciones de "Validar Solicitud" (lo que la app debe replicar en el motor de reglas).** Obligatorios: `id`, `LoanDisk_Branch_ID` numérico, `C_dula_ID`, `Nombre_Completo`, `Fecha_Inicio_Descuento`, `Banco_Desembolso`, `Numero_de_Cuenta`, `Tipo_de_Cuenta`, `ID_Solicitante`. `Monto_Solicitado ∈ {100,150,200,300}` (solo si viene). `Tasa_Nominal > 0`. `Cuotas = 6` (fijo). Idempotencia: `Prestamo_No` y `Referencia_de_Transferencia` vacíos. Las 4 `Sign_Status_* = COMPLETED` (no filtra por `Estado_Solicitud`). Nombre partido en primera palabra / resto. Teléfono sin `+507` ni no-dígitos. `fecha_primer_pago = Fecha_Inicio_Descuento` en `dd/mm/yyyy`. **Ciclo por el día de `Fecha_Inicio_Descuento`:** 10 o 25 → esquema 4646; 15, 28, 29, 30 o 31 → esquema 4418; cualquier otro día → error "no cae en quincena de planilla" y correo.

**Payload LoanDisk — borrower** (`POST https://api-main.loandisk.com/75055/{branch}/borrower`, form): `borrower_unique_number` ← `C_dula_ID`; `borrower_firstname`, `borrower_lastname`; `borrower_mobile` ← `Tel_fono` sin 507; `borrower_email` ← `Email1`; `borrower_business_name` ← `Lugar_de_Trabajo`; custom fields `custom_field_27898` (Bank Account ← `Numero_de_Cuenta`), `custom_field_27899` (Bank ← `Banco_Desembolso`), `custom_field_27951` (Identificación ← cédula), `custom_field_28102` (Account Type ← `Tipo_de_Cuenta`). No envía fecha de nacimiento, género, dirección ni salario.

**Payload LoanDisk — loan** (`POST /75055/{branch}/loan`):

| Campo | Valor / expresión | Origen |
|---|---|---|
| `borrower_id` | del create o de la búsqueda por cédula | LoanDisk |
| `loan_status` | `Open` | constante |
| `loan_application_id` | `ID_Solicitante` tal cual (**"SO -00078", con espacio**) | CRM |
| `loan_product_id` | **383523** ("Micropago Flat 1025") | Config MP |
| `loan_disbursed_by_id` | **285809** (ACH) | Config MP |
| `loan_principal_amount` | `Monto_Solicitado` | CRM |
| `loan_released_date` | fecha de ejecución (`$now` America/Panama, dd/MM/yyyy) | N8N |
| `loan_interest_method` | `flat_rate` | Config MP |
| `loan_interest_type` | `percentage` | constante |
| `loan_interest_period` | `Month` | Config MP |
| `loan_interest` | `Number(Tasa_Nominal).toFixed(4)` → "24.0000" | CRM |
| `loan_duration_period` / `loan_duration` | `Months` / **3** | Config MP |
| `loan_payment_scheme_id` | **4646** (10-25) o **4418** (15-30) según el día de inicio | Config MP + regla |
| `loan_num_of_repayments` | **6** | Config MP |
| `loan_decimal_places` | `round_off_to_two_decimal` | constante |
| `loan_first_repayment_date` | `Fecha_Inicio_Descuento` dd/mm/yyyy | CRM |
| `description` | `Lugar_de_Trabajo` | CRM |
| fees / FECI / custom fields del loan | **ninguno** | — |

Otras constantes de "Config MP": `montos_validos = [100,150,200,300]`, `llamar_bg: true`, **`bg_ambiente: 'prod'`** (comentario: "PRODUCCION desde 1-oct-2026 (prueba con Antonio, autorizada por Gianclaudio)"; el comentario del propio campo dice "DINERO REAL, pendiente de aprobacion de Diego"), `bg_url_prod = https://automation.isthmuscap.com/webhook/bg-crear-transferencia`, `bg_url_qa = …/bg-crear-transferencia-qa`. La descripción del workflow está desactualizada (dice producto 383112 y BG desactivado).

**Llamada al 06.** HTTP POST (no Execute Workflow) a `bg_ambiente === 'prod' ? bg_url_prod : bg_url_qa`, `neverError: true`, con `crm_id, monto, nombre_beneficiario` (← `Titular_Cuenta_Completo` o el nombre), `id_solicitante, cuenta_beneficiario, banco_beneficiario, tipo_cuenta, email_beneficiario`. **Después del POST no hay ningún paso**: no valida la respuesta ni escribe nada en CRM; `Referencia_de_Transferencia` la escribe el 06.

**Manejo de errores.** `neverError: true` en las 5 llamadas externas (4 LoanDisk + BG), sin reintentos ni errorWorkflow. "Buscar Prestamo Existente" trata cualquier respuesta sin `loan_id` (404, error de auth, caída) como "no existe" → idempotencia débil. "Resolver Borrower ID" hace `throw` sin correo. "CRM - Guardar Prestamo" sin neverError: si falla, el préstamo queda creado en LoanDisk sin `Prestamo_No` en CRM. Solo hay correo de aviso en fallo; ninguno de éxito ni al cliente.

**Ejecuciones guardadas (solo 5):**

| id | Estado | Inicio (UTC) | Modo | Resultado |
|---|---|---|---|---|
| 29293 | success | 2026-09-30 20:55 | webhook | SO-00078: creó el préstamo **11909205**; BG simulado |
| 29328 | success | 2026-09-30 22:52 | webhook | SO-00078: rechazado "Ya tiene prestamo (11909205)"; correo |
| 29375 | success | 2026-10-01 02:22 | **manual** (trigger fijado) | SO-00078: creó **11909610**; BG simulado (`llamar_bg: false`) |
| 29573 | success | 2026-10-01 15:58 | webhook | SO-00079: rechazado "Ya existe el prestamo **11909301** en LoanDisk para SO -00079"; correo |
| 29580 | success | 2026-10-01 16:03 | **manual** (trigger fijado) | SO-00079: creó **11913796**; **BG prod llamado** |

**Préstamo 11909610 (SO-00078, ejecución 29375; request reconstruido).** borrower_id 8083050 (el create devolvió "Unique Number is not unique"; la búsqueda por cédula devolvió **2 borrowers** y se tomó el primero); `loan_application_id "SO -00078"`, producto 383523, disbursed_by 285809, principal 100, released 30/09/2026, flat_rate 24.0000 % Month, 3 Months, esquema 4646, 6 cuotas, first_repayment 10/10/2026. Respuesta: `{"loan_id":"11909610"}`, HTTP 200, **sin estado ni calendario**. CRM: `Prestamo_No = 11909610`, `Pendiente Desembolso`.
**Préstamo 11913796 (SO-00079, ejecución 29580).** borrower_id 8084875 (creado), principal **300**, released 01/10/2026, mismos parámetros, esquema 4646, first_repayment 10/10/2026. Respuesta `{"loan_id":"11913796"}`, sin calendario. CRM actualizado. BG prod llamado con monto 300, Banco Nacional, Ahorros (ver 1.5).
**Calendario de cuotas:** LoanDisk solo devuelve `loan_id`; ningún nodo consulta el cronograma, por lo que **no está en ninguna ejecución**. Las cuotas 28.67 / 86.00 que figuran en CRM son `Letra_Mensual`, calculadas antes, no leídas de LoanDisk. Pendiente Brief 06: leer el cronograma por API (solo lectura) y fijarlo como fixture.

### 1.5 06 QA (`EQOqUBQp1N60zFlG`) y 06 prod (`GTFFlEfXa0LOTtnF`)

**Contrato de entrada (ambos, `body.*`):** `crm_id`, `monto`, `nombre_beneficiario`, `cuenta_beneficiario`, `banco_beneficiario` (texto exacto: "Banco General", "BAC", "Banistmo", "Caja de Ahorros", "Banco Nacional", "Global Bank"; otro valor → error), `tipo_cuenta` ("Cuenta de Ahorros", "Cuenta Corriente", "Ahorros", "Corriente"; si falta → 4 = ahorros), `id_solicitante`, `email_beneficiario` (**se ignora**: el correo va fijo a z\*\*\*@isthmuscap.com). No hay nodo ni trigger de Monday: el 06 prod es un webhook genérico que **comparten** Seguridad Unida (desde `5wHL8Ut1ZT8SUZ2B`) y el flujo MP; nada distingue el origen y la descripción "DESEMBOLSO MP <id_solicitante>" es fija para cualquier llamador.

**Nodos (orden).** Webhook → "BG - Autenticar" (GET `/autenticacion/autenticar`, devuelve `Token`) → "Guardar Token" → "Limpiar Campos" (Code: mapea banco → código BG **71** Banco General, **1384** BAC, **26** Banistmo, **770** Caja de Ahorros, **13** Banco Nacional, **1151** Global Bank; tipo de cuenta → **4** ahorros / **3** corriente; normaliza el nombre sin acentos ni ñ en MAYÚSCULAS; descripción "DESEMBOLSO MP <id>") → "BG - POST Desembolso" (POST `/h2h/transaccion/individuales`) → "Guardar Codigo Pago" → PATCH CRM `Referencia_de_Transferencia` → correo.

**Payload BG** (`POST https://conexionbg.bgeneral.cloud/h2h/transaccion/individuales` en prod; QA en `api-iqy.us-east-a.apiconnect.ibmappdomain.cloud/bg-stage-0/bg-h2h-qa2/...`), body `{ "transacciones": [ { … } ] }`:

| Campo | Valor / expresión | Notas |
|---|---|---|
| `descripcion` | "DESEMBOLSO MP <id_solicitante>" | mayúsculas, sin acentos |
| `monto` | `monto` | QA lo convierte con `Number()`; prod lo pasa tal cual |
| `fechaInicial` | `$now.toISO()` | sin programación |
| `trnPropia` | `false` | constante |
| `codigoProducto` | `3` | producto de la cuenta origen |
| `cuentaOrigen` | **`0301000001265`** (prod) / `0301011367700` (QA) | constante |
| `correo` | fijo z\*\*\*@isthmuscap.com | ignora `email_beneficiario` |
| `nombreBeneficiario` | nombre normalizado | |
| `codigoBanco` | tabla de "Limpiar Campos" | |
| `codigoProductoBeneficiario` | 4 ahorros / 3 corriente | |
| `numeroCuentaBeneficiario` | `cuenta_beneficiario` | string |
| `secuencial` | `1` | constante |

Sin campo de moneda ni flag de ambiente: el ambiente lo define solo la URL de cada nodo. Autenticación: client-id y client-secret de BG van **en texto plano dentro de los nodos HTTP** (prod y QA; prod además en dos nodos QA deshabilitados), no en credenciales de N8N; el `Token` devuelto va en la cabecera de autorización del POST.

**Respuesta BG** (vista en ejecuciones): `status.returnStatus.returnCode` (`U0000` = OK), `body.resultadosTransaccion[0].{secuencial, estadoTransaccion ("PA" = pendiente de aprobación), codigoPago}`. **Write-back:** solo `Referencia_de_Transferencia` en `Solicitudes_Microprestamo` (`QA-<codigo>` en QA; el código sin prefijo en prod). No escribe `Aprobaciones_BG` ni `Estado_Solicitud`, ni Monday. **Correo:** prod a d\*\*\*@ y g\*\*\*@isthmuscap.com, asunto "⏳ Transferencia Pendiente de Aprobación - {nombre}", HTML con cuenta destino completa y código, pide aprobar en Banca en Línea; QA a g\*\*\*@ ×2 con asunto "[PRUEBA QA] …". Credenciales: CRM `V8ToVmg60xSjZasl`, Gmail `l3e9P4UxBqKXKir4`.

**Diferencias prod vs QA (no son idénticos salvo ambiente):** QA arma el body con `JSON.stringify`, prod con una plantilla de texto (frágil ante comillas en el nombre o un monto con "="); QA tiene `neverError` + `fullResponse` en el POST y un Code que **lanza error si no hay `codigoPago`**; prod no valida el código (deja `null` y sigue), el PATCH a CRM tiene `onError: continueRegularOutput` (fallo ignorado) y conserva dos nodos QA deshabilitados ("BG - Autenticar1", "BG - POST Desembolso") y una credencial residual `lRBD9utZoqJjYHEW`. QA limpia la entrada (`clean()`, `Number`); prod no.

**Ejecuciones.** 06 QA: 29534 (error, 2026-10-01 14:59) y 29536 (success, 15:00, manual con pinData; entrada SO-00078 monto 100 BAC; respuesta `U0000`, `PA`, **codigoPago 12317**; CRM "record updated"). 06 prod: 29256 (error, 2026-09-30 18:46) y **29581 (success, 2026-10-01 16:03 UTC = 11:03 Panamá, modo webhook, llamada interna desde el 05 v2 ejecución 29580)**: entrada SO-00079, monto 300, Banco Nacional, Ahorros; respuesta `U0000`, `PA`, **codigoPago 18524**. Anomalía: "Guardar Codigo Pago" corrió dos veces; la segunda vino del nodo deshabilitado "BG - POST Desembolso" con código `null` (un nodo deshabilitado deja pasar los datos). **Verificado en CRM el 02-oct-2026:** SO-00079 conserva `Referencia_de_Transferencia = 18524` (no fue pisado por "null"); `Aprobaciones_BG` sigue vacío (ningún workflow lo escribe). El 06 prod se editó a las 16:04:30 UTC y esa conexión ya no existe.

### 1.6 Credenciales de N8N (`list_credentials`: 14, proyecto personal de Gianclaudio)

| id | Nombre | Tipo | Uso MP |
|---|---|---|---|
| `V8ToVmg60xSjZasl` | Zoho account | zohoOAuth2Api | CRM en 05 v2 y 06 (sin WorkDrive) ✅ |
| `lRBD9utZoqJjYHEW` | Zoho Sign WorkDrive OAuth2 | oAuth2Api | WorkDrive y Sign (04) ✅; aparece residual en 05 v2 y 06 prod |
| `l3e9P4UxBqKXKir4` | Gmail account 2 | gmailOAuth2 | Correos MP (gestionprestamos@ según §18; el nombre de la credencial no lo confirma) ✅ |
| `YE6pWD9tPDLeC7rJ` | Gmail Facturasfic | gmailOAuth2 | **No usar** para MP (§18) |
| `7sugiv81vzswd6ra` | Gmail account | gmailOAuth2 | otro |
| `qGu8n7birqwFQ1lL` | SMTP account | smtp | otro |
| `wKnZCYtytaI06wP1` / `4auQ3tA79ga9ziUt` | Header Auth account / account 2 | httpHeaderAuth | uso no visible (¿LoanDisk?) |
| `UgCleHysvKlI78RI` | Sectigo Intermediate CA | httpSslAuth | no usado por los 06 |
| `uLjh3KP3G57cmbgp` / `98Vksw5NyJlbOkLs` | Monday.com account / monday.com account | mondayComApi / mondayComMcpOAuth2Api | flujo Monday |
| `LNdCU5gaYsIpU8na`, `Mn4MTtWDkFmqBlnp` | Google Drive / Sheets | | otro |
| `eabRh5flaGNB5wrf` | Anthropic account | anthropicApi | otro |

**No existen** credenciales para: **Meta WhatsApp MP** (pendiente de crear; §14), **Banco General** (claves en texto plano en los nodos), **LoanDisk** (Basic en texto plano en 4 nodos del 05 v2 y 3 del 5wHL8), **IDAnalyzer** (ver 1.2).

### 1.7 Anomalías detectadas en los nodos (resumen; detalle y controles en `docs/RIESGOS.md` R23–R33)

Secretos en texto plano (BG prod/QA, LoanDisk Basic, JWT de Monday en 5wHL8, token de Meta WhatsApp en el 03); webhooks sin autenticación (`bg-crear-transferencia` prod, `mp-carta-firmada-v2`, `mp-kyc-callback`, `mp-sign-docs`); cableado de los dos IF del 03 roto en `cb696e63…` y **corregido en `37e44e08…`** (0.1); WhatsApp del 03 al final de la rama (residual); `IDAnalyzer_Transaction_ID` siempre null; WhatsApp como texto libre (fuera de la ventana de 24 h falla en silencio) con enlace http; rama de rechazo KYC sin envío; redacción de datos desactivada (PII y tokens de filevault en el historial); `bg_ambiente = 'prod'` y `llamar_bg = true` escritos en un Code node de un workflow llamado "(BORRADOR)"; los dos préstamos reales salieron de ejecuciones manuales con el trigger fijado; SO-00078 tiene dos préstamos creados (11909205 y 11909610) y SO-00079 tuvo un préstamo previo 11909301 con número SO; una cédula con dos borrowers en LoanDisk; `neverError: true` en todas las llamadas externas; idempotencia débil; valores financieros fijos en código; token de sesión de BG guardado en el historial de ejecución QA; prod no valida `codigoPago` e ignora el fallo del PATCH a CRM; nodos deshabilitados que dejan pasar datos; sin 07 ni polling; `email_beneficiario` ignorado; sin moneda en el payload BG.

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
| Orden real | En el flujo del cliente el formulario llega **después** del KYC: al aprobar, **IDAnalyzer redirige al formulario**; el 03 envía además el enlace por WhatsApp como respaldo (Paso 1; precisión 02-oct-2026). |
| Observación | **No existe un campo NUC** en `Solicitudes_Microprestamo` ni en `Afiliados`; el NUC debe vivir en `Contacts` u otro módulo. Confirmar en el Brief 03/05 antes de `ensure_cliente`. |

### Paso 1 — 03 KYC (IDAnalyzer DocuPass) — corregido y publicado por Gianclaudio el 02-oct-2026 (manualmente en N8N, fuera de esta sesión)

| | Detalle |
|---|---|
| Workflow | "03 - MP KYC - Callback IDAnalyzer" `n4uerlMucRTnR8Bu` ✅ (1.2). Profile IDAnalyzer `53067a87b10a41bd8771c34e9b7c53c4` 📄 §2 (llega en el payload; se configura en el 02). Versión corregida publicada por Gianclaudio manualmente en N8N y fuera de esta sesión (`37e44e08…`, 02-oct-2026 02:19 UTC; desde esta sesión no se publicó ni modificó ningún workflow); **sin ejecuciones aún**: la valida el próximo KYC real. |
| Entradas | Callback de IDAnalyzer con el resultado de la verificación (cédula, sesión, estado aprobado/rechazado). Llega normalmente **antes** de que exista la solicitud. |
| Comportamiento (v1 corregida) | 1. Al **aprobar** IDAnalyzer, el **WhatsApp con el enlace del formulario sale de inmediato** (respaldo: el camino principal es la redirección de IDAnalyzer al formulario), sin depender de encontrar la solicitud (antes dependía de ella y casi nunca salía). Si el WhatsApp falla, **no frena** lo demás. 2. En paralelo busca la solicitud por cédula; si no existe, **reintenta cada 2 min hasta 15 veces (30 min)**. 3. Sin solicitud a los 30 min → correo desde **gestionprestamos@** a Gisela y a Gianclaudio con la cédula y el enlace de la ejecución, para reprocesarla. 4. Si la encuentra: guarda `IDAnalyzer_Session_ID` en CRM ✅ (presente en SO-00078/79) y sube **3 reportes** (Transaction, Face, Docupass Audit) al folder KYC (`Folder_ID_KYC`). |
| Validaciones | Resultado/score de DocuPass; selfie con instrucción visual 📄 §4.1. |
| Salidas | WhatsApp al solicitante; `IDAnalyzer_Session_ID` (+ `IDAnalyzer_Transaction_ID`) en CRM; 3 PDF en `Folder_ID_KYC`; correo de excepción a operaciones si no hay solicitud. |
| Lección N8N | El **Retry** de N8N reutiliza la salida guardada del nodo anterior; para reprocesar hay que **re-ejecutar el workflow completo con el payload original** (confirmado en 29583/29584). Para la app: `webhook_inbox` conserva el payload original de cada callback y el reproceso siempre parte de él. |
| **Contraste con los nodos (02-oct-2026)** | La lectura de `cb696e63…` detectó las salidas false de los dos IF sin conectar; **recableado en `37e44e08…` (02:19 UTC) y verificado por MCP**: reintentos y aviso cuando no hay solicitud, proceso único cuando sí la hay. Residuales (prioridad Baja, precisión 02-oct: IDAnalyzer redirige al formulario; el WhatsApp es respaldo): WhatsApp al final de la rama (hasta 30 min en el caso normal) y como texto libre, `IDAnalyzer_Transaction_ID` null, token de Meta en el nodo. Pendiente validación en vivo. |
| Regla para la app | **Decisión 02-oct-2026 (Prompt Maestro §19):** la solicitud se crea en `borrador` en el paso 1 del wizard y la sesión KYC nace asociada a ella (nunca una sesión KYC sin solicitud); el callback trae el id de la solicitud. `mp_kyc_callback` conserva como defensa la tolerancia al orden KYC → solicitud (payload original en `webhook_inbox`, cola de huérfanos en `/admin` y alerta a operaciones). El wizard es reanudable con OTP. El WhatsApp con el enlace es respaldo porque IDAnalyzer redirige al formulario al aprobar. |

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
| Validaciones | Descarta el evento duplicado `RequestSigningSuccess` + `completed` ✅; exige `request_status = completed` y `request_name` con "MP -" ✅; sin `webhook_inbox` ni `idempotency_key` (1.3). Credencial Zoho con WorkDrive `lRBD9utZoqJjYHEW` ✅. |
| Salidas | `Sign_Status_*` y `Sign_Detalle_*` por documento ✅ (`COMPLETED` ×4; `RECALLED` en SO-00077 cancelada). Al completarse: descarga de los **4 PDF por separado** ("<documento> - <SO>.pdf") y del certificado ("MP - Certificado de firmas - <SO>.pdf") a `Folder_ID_Documentos_Firmados`; la Carta también a `Folder_ID_RRHH` ✅ (1.3). **No escribe** `Estado_Solicitud` ni `WorkDrive_Docs_Firmados_URL`. **Dispara el 05 v2 por HTTP directo** (`mp-carta-firmada-v2`) ✅, no por cambio de estado. |

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
| KYC IDAnalyzer con redirección al formulario al aprobar y callback tolerante al orden (WhatsApp de respaldo, búsqueda por cédula con reintentos 2 min × 15, correo de excepción a operaciones) | Sesión KYC siempre asociada a la solicitud en `borrador` del paso 1 (§19); adaptador `kyc_provider`; `webhook_inbox` con payload original para reproceso; reutilización de KYC vigente < 12 meses |
| OTP/enlace por WhatsApp independiente de la solicitud | Plantilla `fic_mp_codigo_acceso` + magic link de respaldo; la solicitud existe en `borrador` desde el paso 1 del wizard (§19), el wizard se reanuda con OTP y el canal nunca depende de ella |
| 7 carpetas WorkDrive por solicitud | 6 carpetas `01_KYC … 06_Desembolso` creadas por N8N (sin Zoho Flow); mapeo en Brief 08 |

## 2. Banco General H2H

- **Endpoint y cuentas (§2, §18):** `conexionbg.bgeneral.cloud`; cuenta origen producción `0301000001265`; QA `bg-h2h-qa2` con cuenta de certificación `0301011367700`.
- **Comportamiento del 06 prod:** no ejecuta la transferencia; la deja **pendiente de aprobación** en Banca en Línea, donde Diego (único firmante, §13.3) aprueba o rechaza. Esto es un control natural contra desembolsos erróneos y debe mantenerse en la app.
- **Selector de ambiente:** `bg_ambiente ∈ {qa, prod}` es una **constante en el Code node "Config MP" del 05 v2** (hoy `'prod'`), que elige la URL del webhook del 06. No existe variable de entorno ni parámetro. La app lo convierte en parámetro de entorno (`qa` en staging y pruebas) y `lib/banking` llama al mismo webhook con el mismo contrato (R26).
- **Campos CRM relacionados con BG (API names reales):** `Aprobaciones_BG` (etiqueta "Codigo Pago", integer), `Referencia_de_Transferencia` (etiqueta "Confirmacion", text), `Banco_Desembolso` (picklist: Banco General, BAC, Banistmo, Caja de Ahorros, Banco Nacional, Global Bank), `Tipo_de_Cuenta` (Cuenta de Ahorros / Cuenta Corriente), `Es_Titular_de_la_Cuenta` (Si/No), `Numero_de_Cuenta` (text), `Titular_Cuenta_Completo` (text), `Folder_ID_Desembolso`, `WorkDrive_Desembolso_URL`.
- **Observado:** al 01-oct-2026 11:09 `Aprobaciones_BG` estaba vacío en SO-00078/79. El 02-oct-2026 SO-00079 generó la transferencia BG con **código 18524**, pendiente de aprobación de Diego en Banca en Línea (validado por Gianclaudio). El `codigoPago 12317` de la prueba QA no quedó en CRM. Confirmar en el Brief 12 que el 07 escribe el código en `Aprobaciones_BG` y la referencia en `Referencia_de_Transferencia`.
- **Estructura del payload de transferencia:** documentada en 1.5 (12 campos: `descripcion, monto, fechaInicial, trnPropia, codigoProducto, cuentaOrigen, correo, nombreBeneficiario, codigoBanco, codigoProductoBeneficiario, numeroCuentaBeneficiario, secuencial`; sin moneda ni cédula del beneficiario; códigos de banco en "Limpiar Campos"). Contrato de entrada del 06 que `lib/banking` debe reproducir: `crm_id, monto, nombre_beneficiario, cuenta_beneficiario, banco_beneficiario, tipo_cuenta, id_solicitante, email_beneficiario`.
- **Autenticación BG:** `GET /autenticacion/autenticar` con client-id/secret → `Token` → cabecera de autorización del POST. Hoy las claves están en texto plano en los nodos (R23).

## 3. LoanDisk

| Dato | Valor | Fuente | Estado |
|---|---|---|---|
| Producto | `383523` "Micropago Flat 1025", Flat Rate, interés sobre el monto original, cuota constante; rango de interés del producto min 18 / max 30 | §18 + Config MP del 05 v2 | **Confirmado** (1.4) |
| Productos que **no** se usan | 369108, 369109, 383112 | §18 | — |
| Ciclo 10-25 | `loan_payment_scheme_id = 4646` | §18 + Config MP | **Confirmado** (1.4) |
| Ciclo 15-30 | `loan_payment_scheme_id = 4418`; pendiente habilitarlo en el producto 383523 | §18 + Config MP | Confirmado el ID; habilitación pendiente (Gisela) |
| Ciclo prohibido | `Bimonthly` (ID 12): por API genera cuotas cada 2 meses | §18 | Regla en `parametros` |
| Branch por afiliado | AF-0033 → `92588`; AF-0031 → `91008` | CRM `Afiliados.LoanDisk_Branch_ID` | Confirmado |
| Herencia del branch a la solicitud | Regla CRM "LoanDisk_BranchID" (create) copia `Afiliados.LoanDisk_Branch_ID` a `Solicitudes_Microprestamo.LoanDisk_Branch_ID` | `getWorkflowRules` | Confirmado (SO-00077/78/79 = 92588) |
| Cuenta LoanDisk | Public Key `75055`, Branch principal `87572` | §2 | — |
| `loan_disbursed_by_id` | **285809** (ACH) | Config MP del 05 v2 (1.4) | Confirmado |
| Método / periodo / plazo / cuotas | `flat_rate` · `percentage` · `Month` · `3 Months` · 6 cuotas · `round_off_to_two_decimal` | Config MP (1.4) | Confirmado |
| Custom fields del borrower | 27898 Bank Account · 27899 Bank · 27951 Identificación · 28102 Account Type | 05 v2 (1.4) | Confirmado |
| `loan_application_id` | `ID_Solicitante` con espacio ("SO -00079") | 05 v2 | Confirmado; normalizar en la app |
| URL base | `https://api-main.loandisk.com/75055/{branch}` (public key en la ruta; Basic en header) | 05 v2 | Confirmado |
| Número de préstamo | Se guarda en CRM `Prestamo_No` (bigint): SO-00078 → `11909610` (referencia §18), SO-00079 → `11913796` | COQL | Confirmado |
| Casos de referencia v1 | **SO-00078 / 11909610** ($100, 24 %, 6 × 28.67, total 172.00) y **SO-00079 / 11913796** ($300, 24 %, 6 × 86.00, total 516.00; BG código 18524) | Gianclaudio 02-oct-2026 + COQL | Confirmado |
| Préstamo histórico de referencia | `16860`: 300.00 → 420.00, 16 %/mes, 5 cuotas de 84.00 | §4.4 | Reproducido en §5 |
| **FECI** | **Exento** para micropréstamos: regla "Small loan: monto original ≤ B/.5,000 → FECI 0 %". El fee "FECI %" (ID `15489`) existe en la cuenta y no debe adjuntarse. | Doc "LoanDisk FECI Configuration Guide" (01-oct-2026) | Confirmado; parámetro de producto `feci_pct = 0` |
| Comisión de cierre, timbres, seguro | **Ninguno**: el loan se crea sin fees ni custom fields | 05 v2 (1.4) | Confirmado; `parametros` arranca con fees = 0 |
| Campos CRM LoanDisk en `Afiliados` sin uso | `Loan_Product`, `Number_of_Payments`, `Repayment_Cycle` (text, vacíos en AF-0031 y AF-0033) | `getFields` + COQL | Documentado; no son fuente |

**Regla (reconfirmada el 02-oct-2026):** las pruebas manuales en LoanDisk **nunca** usan números `SO-` ni numeración en secuencia: un préstamo de prueba creado como "SO -00079" bloqueó el préstamo real de SO-00079. Usar prefijo propio (p. ej. `TEST-`) y branch de pruebas.

## 4. Cómo viaja la tasa

```
CRM Afiliados.Taza_de_Interes (percent; Diego la coloca)
   └─(copia al crear la solicitud: Creator/Deluge o N8N — tramo PENDIENTE de confirmar)─▶
CRM Solicitudes_Microprestamo.Tasa_Nominal = Tasa_Efectiva (percent)
   └─(05 v2: "Validar Solicitud" interes = Number(Tasa_Nominal) > 0 → toFixed(4) = "24.0000")─▶ LoanDisk loan_interest (flat_rate, percentage, Month)
```

Evidencia:
- AF-0033 "Prueba Inc." tiene `Taza_de_Interes = 24`; sus solicitudes SO-00077, SO-00078 y SO-00079 tienen `Tasa_Nominal = Tasa_Efectiva = 24`. AF-0031 "Acme Corporation Inc." tiene `Taza_de_Interes = 4`.
- Las acciones de campo "Asignar Tasa Nominal 18" y "Asignar Tasa Efectiva 18" (valor fijo 18, creadas 04/05-may-2026) existen pero están **desasociadas** (`associated: false`): la tasa fija de la v0 ya no aplica. Confirma §16.2.
- Ninguna regla de workflow de CRM copia la tasa del afiliado a la solicitud. El 05 v2 la lee ya puesta en `Tasa_Nominal`; un comentario del nodo dice que "el Flow" la copia desde el afiliado, es decir, Zoho Flow / Creator al crear la solicitud (se confirma con el código Deluge, §7). El 05 v2 **no valida** la tasa contra el rango del producto (18–30) ni contra parámetros.

Plazo, frecuencia y cuotas:
- `Cuotas` es picklist `6` / `9` (quincenas). Las tres solicitudes observadas usan `6` (= 3 meses). No existe `12`, `18` ni `24` (ver `docs/RIESGOS.md` R14).
- `Letra_Mensual` (etiqueta real: "Letra Quincenal", currency): 28.67 para $100 al 24 % con 6 cuotas; 86.00 para $300 al 24 % con 6 cuotas. Coincide con la fórmula §4.6-a (ver §5).
- Frecuencia: `Afiliados.Frecuencia_de_Planilla` es **multiselección** con valores `Semanal`, `Quincenal 10-25`, `Quincenal 15-30`. AF-0031 y AF-0033 tienen `["Quincenal 10-25"]`.
- `Fecha_Inicio_Descuento` (date) = `2026-10-10` para solicitudes creadas el 29-sep, 30-sep y 01-oct con ciclo 10-25: coincide con la regla "próxima fecha de planilla estrictamente posterior" (§4.6-b).

## 5. Letra y redondeo

Script: `tests/inventario/letra_v1.mjs` (`node tests/inventario/letra_v1.mjs`, exit 0), actualizado a la regla §4.6-a v5.1 (02-oct-2026). Salida del 02-oct-2026:

```
SO-00078 / 11909610    LoanDisk cuotas= 6 cuota=28.67 (OK) ultima=28.65 (OK) total=172.00 (OK) suma=OK [cuota×cuotas=172.02, dif 0.02]
SO-00079 / 11913796    LoanDisk cuotas= 6 cuota=86.00 (OK) ultima=86.00 (OK) total=516.00 (OK) suma=OK
16860                  LoanDisk cuotas= 5 cuota=84.00 (OK) ultima=84.00 (OK) total=420.00 (OK) suma=OK
§4.6 $300 4% 3m        PM       cuotas= 6 cuota=56.00 (OK) ultima=56.00 (OK) total=336.00 (OK) suma=OK
§4.6 $300 4% 6m        PM       cuotas=12 cuota=31.00 (OK) ultima=31.00 (OK) total=372.00 (OK) suma=OK
§4.6 $300 4% 9m        PM       cuotas=18 cuota=22.67 (OK) ultima=22.61 (OK) total=408.00 (OK) suma=OK [cuota×cuotas=408.06, dif 0.06]
§4.6 $300 4% 12m       PM       cuotas=24 cuota=18.50 (OK) ultima=18.50 (OK) total=444.00 (OK) suma=OK

Cuota, última cuota y total coinciden con LoanDisk / §4.6 en todos los casos.
```

Conclusiones:
1. La **cuota** `redondear2(total / cuotas)` (equivalente a `monto/cuotas + monto×tasa/100/2`) reproduce exactamente las cuotas reales de CRM/LoanDisk (28.67 y 86.00) y el préstamo 16860 (84.00).
2. El **total** real de LoanDisk es `capital + monto × tasa × meses / 100` (interés flat). La definición anterior de §4.6-a (`cuota × cuotas`, v5) difería en centavos cuando la cuota no es exacta: 172.02 vs 172.00 (SO-00078 / 11909610; SO-00077 tenía los mismos parámetros y fue cancelada) y 408.06 vs 408.00 (tabla §4.6). SO-00079 / 11913796 no tiene diferencia: 516.00 por ambas vías.
3. **Regla aprobada el 02-oct-2026 (Gianclaudio) y escrita en §4.6-a v5.1:** `total_pagar = capital + interés flat`; cuota redondeada a centavos; la **última cuota absorbe la diferencia** (SO-00078: 5 × 28.67 + 28.65 = 172.00; $300 al 4 % a 9 meses: 17 × 22.67 + 22.61 = 408.00). El calendario que devuelve LoanDisk es la fuente de verdad del snapshot: `mp_loandisk_crear` lo guarda en `evaluaciones.snapshot` y, si difiere del total o de las cuotas calculadas, **alerta** al analista y a Diego; nunca se absorbe en silencio ni se recalcula por fórmula. Pendiente Brief 06: confirmar en el cronograma real del 11909610 que LoanDisk también carga los centavos en la última cuota (si los reparte distinto, manda LoanDisk y la alerta lo señala). **Nota del inventario de nodos:** la respuesta de LoanDisk al crear el préstamo solo trae `loan_id`; ningún workflow consulta el cronograma, así que la última cuota de 28.65 es aritmética de la regla aprobada, no un dato observado.
4. **Secuencia Sign → LoanDisk (afecta a Briefs 06 y 10).** Hoy, y según §8 (`mp_loandisk_crear` se dispara en `docs_firmados`), el préstamo en LoanDisk se crea **después** de firmar los 4 documentos, pero §4.6-e genera los documentos desde el snapshot congelado al enviar. Por tanto `monto_total` del Contrato (sección 8) sale de la fórmula aprobada en el punto 3, no del calendario de LoanDisk; el calendario gobierna importes y fechas por cuota a partir de la creación del préstamo. Pendiente: abrir el Contrato firmado de SO-00078 y anotar qué puso la v1 en `monto_total` (172.00 o 172.02).

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

### 6.4 Dónde vive el NUC (decisión 3, 02-oct-2026)

El Número Único de Cliente **ya existe** en CRM como **`Contacts.C_digo_nico`** (etiqueta "Código único", text 255, custom, **sin restricción de unicidad**), formato `IS-00NNNN` (p. ej. `IS-004408`); 69 contactos lo tienen al 02-oct-2026 y la numeración no sigue el orden de creación (se asigna fuera de CRM o al convertir el lead). `Expedientes` (otra línea de negocio) tiene el mismo campo. **No hay** campo NUC en `Solicitudes_Microprestamo` ni en `Afiliados`, ni lookup de la solicitud a `Contacts`: hoy el enlace solo puede hacerse por cédula (`Solicitudes_Microprestamo.C_dula_ID` ↔ `Contacts.C_dula_o_Pasaporte`). **Propuesta (no crear campo nuevo):** `ensure_cliente(cedula)` busca el `Contact` por cédula, lee o asigna `C_digo_nico` con la misma secuencia `IS-`, y el Brief 05 añade a `Solicitudes_Microprestamo` un lookup `Contacto` (cambio en CRM con aprobación) para dejar de depender de la cédula como llave. Pendiente Gianclaudio: confirmar que `IS-00NNNN` es el NUC oficial y quién asigna la secuencia.

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
| Copia de la tasa afiliado → solicitud | Zoho Flow / Creator al crear la solicitud (comentario en el 05 v2) | Ver §4 | Pendiente de confirmar en Deluge |

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
- **Discrepancia con §13.2:** Contrato y Carta conservan un paso `APPROVER` de Isthmus (Gisela) y la Carta tiene 3 pasos. **Decisión 02-oct-2026: queda como está hasta que Diego decida**; registrado como pendiente de Diego (R13, §12).
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
- Plan de la organización: **Free** (Gianclaudio, 02-oct-2026); el MCP no expone el plan. **Upgrade a Pro previsto para el 03-oct-2026.**
- **`isthmus-mp` no existe.** Pendiente upgrade a Pro antes de crearlo (Brief 03). Ver `docs/RIESGOS.md` R10.

## 11. Accesos

| Acceso | Estado 02-oct-2026 | Evidencia |
|---|---|---|
| SSH al VPS desde VS Code | OK | Esta sesión corre en `isthmus-n8n` (`5.78.214.136`) como `root`; Brief 01 crea `deploy`. Contenedores activos: `cotizador-app` :3001, `maxmotors-app` :3002, `n8n-n8n-1` :5678, `n8n-postgres-1`, `gotenberg` :3000. Node 22.22.1, npm 9.2.0, Docker 29.7.2, Caddy, Python 3.14. |
| DNS `mp.isthmuscap.com` | **Sin registro A** | `dig +short` vacío. Idem `staging-mp.` y `microprestamos.`. `automation.isthmuscap.com` → 5.78.214.136. Crear en el Brief 01. |
| Supabase `isthmus-mp` | **Pendiente** (upgrade Pro) | §10 |
| Token WhatsApp en `.env` | OK | `.env` con permisos 600 (root); 5 claves `WHATSAPP_*`; `WHATSAPP_PHONE_NUMBER_ID = 1184886231372996`, `WHATSAPP_BUSINESS_ACCOUNT_ID = 4466216373701343`, `WHATSAPP_APP_ID = 1360854289567229`, `WHATSAPP_TEMPLATE_OTP = fic_mp_codigo_acceso` (coinciden con §14); `WHATSAPP_TOKEN` presente (no se imprime). Pendiente Brief 04: validar con el Access Token Debugger y planificar rotación. |
| Credencial N8N `Meta WhatsApp MP` | **Sin confirmar** | Bloqueo del MCP n8n (sección 0). Gianclaudio la crea o confirma. |
| Playwright en el VPS | **No soportado nativo** | Playwright 1.56 no soporta Ubuntu 26.04 (`npx playwright install chromium` falla) y el MCP de Playwright no encuentra Chrome. Brief 02: correr Playwright en Docker (`mcr.microsoft.com/playwright`). Las capturas del Brief 00 se hicieron con Gotenberg (`gotenberg/gotenberg:8`, v8.34.0, contenedor existente). |
| Remoto git | **OK** (02-oct-2026) | `origin` = `https://github.com/isthmus-capital/mp-app.git` (privado), `main` sincronizado; regla en `CLAUDE.md`: cada commit va seguido de `git push`. R11 cerrado. |
| Diseño: 5 pantallas | **Pendiente** (cierre del Brief 01) | Decisión 02-oct-2026 (§19): se preparan en HTML con los tokens FIC y se revisan con Gianclaudio en celular (no con Diego); ver `docs/design/README.md`. |

## 12. Pendientes y bloqueantes

**Bloqueantes**
1. ~~MCP n8n re-autenticado~~ **Resuelto el 02-oct-2026**: sección 1 completada por MCP (05 v2, 06 QA/prod, credenciales; 03/04 en 1.2–1.3). **Criterio de aceptación 1 del Brief 00: cumplido** en IDs LoanDisk y payload BG; queda abierto solo el cronograma real de LoanDisk (no visible en N8N; se lee por API en el Brief 06).
2. **Supabase Pro** antes del Brief 03 (previsto 03-oct-2026).
3. ~~Remoto git o backup off-site antes del Brief 01~~ **Resuelto el 02-oct-2026**: `origin` privado en GitHub (`isthmus-capital/mp-app`), `main` sincronizado, push tras cada commit.

**Pendientes (no bloquean el Brief 01/02)**
4. Código Deluge de `mp_enviar_a_zoho_sign1` (Gianclaudio lo pega).
5. ~~Confirmar `loan_disbursed_by_id`, esquemas y fees en el 05 v2~~ Resuelto (1.4): 285809, 4646/4418, sin fees.
6. Gisela: habilitar el esquema 15-30 (4418) en el producto 383523; confirmar cómo LoanDisk reparte los centavos en el cronograma del 11909610.
7. Diego: el paso APPROVER de Gisela en los templates Contrato y Carta **queda como está hasta que él decida** (decisión 02-oct-2026, R13); semántica de `L_mite_para_nuevos_descuentos` y `Fecha_de_corte_de_planilla`.
8. Crear `Modo_Validacion` en CRM `Afiliados` y ampliar picklists `Cuotas`/`Monto_Solicitado` (Brief 05, cambios en CRM con aprobación).
9. Crear DNS `mp.` y `staging-mp.` (Brief 01).
10. Credencial N8N `Meta WhatsApp MP`: **no existe** (`list_credentials`); crearla con el token del `.env` (Gianclaudio) antes del Brief 04.
11. Preparar las 5 pantallas en HTML con los tokens FIC al cierre del Brief 01 y revisarlas con Gianclaudio en celular (decisión 02-oct-2026, §19; no con Diego); congelar lo aprobado en `docs/design/` antes del Brief 02.
12. Brief 02: Playwright en Docker (no hay soporte nativo de Chromium en Ubuntu 26.04).
13. Validar en vivo el 03 KYC corregido (publicado el 02-oct-2026) con el próximo KYC real; anotar el resultado aquí.
14. Diego: aprobar en Banca en Línea la transferencia BG código 18524 de SO-00079. **No existe 07 ni polling**: el estado final no llega a CRM; `Aprobaciones_BG` nunca se escribe. La app implementa `mp_bg_polling` (Brief 12).
16. **Seguridad (urgente, fuera del alcance de la app):** mover a credenciales de N8N y rotar las claves de BG (prod y QA) y la Basic de LoanDisk que están en texto plano en los nodos del 05 v2, 06 y 5wHL8; poner autenticación a los webhooks `bg-crear-transferencia` y `mp-carta-firmada-v2`. Cambios en N8N: se muestran y se aprueban antes (CLAUDE.md).
17. LoanDisk (Gisela): revisar los préstamos huérfanos de prueba 11909205 (SO-00078) y 11909301 (SO-00079, con número SO) y el borrower duplicado de la cédula de SO-00078.
18. Confirmar con Gianclaudio que `Contacts.C_digo_nico` (`IS-00NNNN`) es el NUC oficial y quién asigna la secuencia (6.4).
19. ~~Verificar y corregir el cableado de los IF del 03~~ **Hecho por Gianclaudio (`37e44e08…`, 02-oct 02:19 UTC), verificado por MCP.** Quedan, en **prioridad Baja** (02-oct: IDAnalyzer redirige al formulario al aprobar; el WhatsApp es respaldo): mover el WhatsApp antes de la búsqueda (hoy saldría hasta 30 min después en el caso normal) y corregir `transaction_id` a `body.transactionId`; **validar en vivo con el próximo KYC real** y anotar el resultado en 0.1.
20. WhatsApp del 03: pasar a plantilla aprobada (`fic_mp_codigo_acceso` o una UTILITY nueva) con enlace https; mover el token de Meta a la credencial `Meta WhatsApp MP`; implementar la rama de rechazo.
21. N8N: activar la redacción de datos en ejecuciones (`redaction.production`) y revisar la retención; los tokens de filevault de IDAnalyzer permiten descargar los reportes KYC sin autenticación.
15. Brief 06/10: abrir el Contrato firmado de SO-00078 y anotar el `monto_total` real (172.00 o 172.02). La redefinición de `total_pagar` en §4.6-a ya está aprobada y escrita (v5.1, 02-oct-2026).
