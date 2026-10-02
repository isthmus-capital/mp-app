# Registro de riesgos — Brief 00
<!-- Paquete: v5 — Brief 00 — 02-oct-2026 -->

**Alcance.** Riesgos operativos, financieros, de seguridad y de cumplimiento del rediseño de micropréstamos: app `mp-app` (Next.js) + Supabase `isthmus-mp` + N8N + Zoho CRM/WorkDrive/Sign + LoanDisk + Banco General H2H + IDAnalyzer + WhatsApp Meta.
**Método.** Matriz probabilidad × impacto (Alta/Media/Baja) → nivel Crítico/Alto/Medio/Bajo. Cada riesgo lleva control preventivo, control detectivo, brief que lo implementa, responsable y estado al 02-oct-2026.
**Fuentes.** `docs/00_PROMPT_MAESTRO.md` (§3, §4.4–4.7, §6, §8, §10, §13, §16–18), `docs/briefs/BRIEF_00_fundacion.md`, precisiones de Gianclaudio (02-oct-2026) e inventario `docs/INVENTARIO_ACTUAL.md`.

## Resumen priorizado

| # | Riesgo | Categoría | Prob. | Impacto | Nivel | Brief(s) | Estado hoy |
|---|---|---|---|---|---|---|---|
| R10 | Supabase en plan Free: pausa por inactividad y sin backups diarios | Operativo | Alta | Alto | **Crítico** | 01, 03 | **Bloqueante** para Brief 03 y producción |
| R11 | Repo sin remoto: un fallo del VPS pierde el código | Operativo | Alta | Alto | **Crítico** | 00, 01 | **Pendiente** (decisión de Gianclaudio) |
| R08 | Desembolso accidental por pruebas contra BG LIVE | Financiero | Media | Alto | Alto | 00, 05, 12 | Política definida; controles técnicos pendientes |
| R12 | Sesión de Claude Code con acceso a N8N que contiene BG LIVE | Seguridad | Media | Alto | Alto | 00, 12 | Mitigado parcialmente (allowlist de tools) |
| R01 | Desembolso a cuenta equivocada | Financiero | Media | Alto | Alto | 06, 07, 12 | Abierto |
| R02 | Doble desembolso | Financiero | Media | Alto | Alto | 03, 12 | Abierto |
| R04 | Fuga de PII | Seguridad / Cumplimiento | Media | Alto | Alto | 01, 02, 03, 04, 17 | Abierto |
| R09 | Parámetro financiero mal configurado por un usuario | Financiero | Media | Alto | Alto | 04, 06, 09 | Abierto |
| R06 | Token Zoho vencido | Operativo | Alta | Medio | Alto | 01, 19 | Abierto (ya ocurrió en v1) |
| R03 | Solicitud aprobada sin aval de RRHH (Camino B) | Cumplimiento | Media | Medio | Medio | 03, 07, 09 | Abierto |
| R05 | Caída de N8N a mitad de flujo | Operativo | Media | Medio | Medio | 01, 03, 08, 19 | Abierto |
| R07 | Discrepancia Supabase ↔ CRM | Operativo | Media | Medio | Medio | 05, 08, 19 | Abierto |

Riesgos adicionales detectados durante el inventario: R13 a R22 (sección final).

---

## R01 — Desembolso a cuenta equivocada
- **Descripción.** La transferencia BG llega a una cuenta que no es del solicitante: error de digitación en el wizard, cuenta de un tercero, banco o tipo de cuenta incorrectos, o cambio de cuenta después de la aprobación.
- **Probabilidad / impacto / nivel.** Media / Alto / Alto.
- **Control preventivo.** (1) Cuenta, banco y tipo validados por formato y por banco en el paso 3 del wizard; `Es_Titular_de_la_Cuenta` obligatorio y titular = nombre KYC. (2) Cuenta congelada en `evaluaciones.snapshot` al enviar; cualquier cambio posterior reabre revisión. (3) Confirmación visual al cliente con cuenta enmascarada antes de enviar y en la notificación de desembolso. (4) Diego ve nombre del titular, banco y cuenta enmascarada en la cola de desembolso antes de aprobar; el 06 prod solo crea la transferencia pendiente que Diego aprueba o rechaza en Banca en Línea (control de dos pasos ya existente).
- **Control detectivo.** `mp_bg_polling` registra el estado BG en `bg_transacciones`; conciliación de `desembolsos` vs `bg_transacciones` vs LoanDisk; notificación WhatsApp al cliente con monto y cuenta enmascarada (el cliente reclama si no la reconoce); Gisela recibe aviso de cada desembolso (§13.3).
- **Brief.** 07 (validación en wizard), 06 (snapshot), 12 (cola de desembolso, polling, notificación).
- **Responsable.** Diego (aprobación), Gianclaudio (controles de app). **Estado:** Abierto.

## R02 — Doble desembolso
- **Descripción.** La misma solicitud genera dos transferencias: reintento del outbox, doble clic en `/admin`, re-ejecución manual de un workflow, o reprocesamiento de un webhook.
- **Probabilidad / impacto / nivel.** Media / Alto / Alto.
- **Control preventivo.** (1) `desembolsos` con `UNIQUE (solicitud_id)` y estado máquina: solo se puede desembolsar desde `desembolso_pendiente` vía `transicionar_solicitud` (RPC atómica). (2) `idempotency_key` en `webhook_outbox` y en el payload BG (referencia única por solicitud); N8N verifica la clave en `webhook_inbox` antes de llamar a BG. (3) Botón de aprobación con OTP y bloqueo optimista (versión de fila). (4) Prohibido ejecutar manualmente el 06 prod desde N8N o desde esta sesión (ver R12).
- **Control detectivo.** `mp_bg_polling` compara transacciones BG por referencia contra `desembolsos`; alerta inmediata si una solicitud tiene más de una transacción `procesada`; conciliación nocturna `mp_reconcile_crm` + cruce con LoanDisk (`loan_disbursed`).
- **Brief.** 03 (esquema, RPC, outbox/inbox), 12 (desembolso y polling).
- **Responsable.** Gianclaudio. **Estado:** Abierto.

## R03 — Solicitud aprobada sin aval de RRHH (Camino B)
- **Descripción.** Un afiliado con `Modo_Validacion = declaracion_rrhh` recibe una aprobación basada solo en lo que declaró el solicitante, sin que RRHH confirme antigüedad, salario y ciclo.
- **Probabilidad / impacto / nivel.** Media / Medio / Medio.
- **Control preventivo.** (1) Regla del motor: en Camino B la transición a `pre_aprobada`/`aprobada` exige `aval_rrhh` registrado (usuario de `/afiliado`, fecha, IP). (2) RLS: solo `afiliado_admin` del `id_afiliado` correcto puede escribir el aval; el analista no puede marcarlo. (3) La bandeja de `/admin` muestra el estado del aval y bloquea el botón de aprobar sin él.
- **Control detectivo.** `audit_events` con el aval como evento propio; reporte diario (`mp_digest_diario`) de solicitudes aprobadas en Camino B sin evento de aval; `mp_reconcile_crm` marca inconsistencia si CRM dice `Aprobada` sin aval en Supabase.
- **Brief.** 03 (RPC/RLS), 07 (wizard Camino B), 09 (bandeja y aval desde `/afiliado`).
- **Responsable.** Gianclaudio (regla), analista/Diego (operación). **Estado:** Abierto. Nota: CRM `Afiliados` hoy no tiene el campo `Modo_Validacion` (ver R21).

## R04 — Fuga de PII
- **Descripción.** Cédulas, cuentas bancarias, salarios, fotos KYC o documentos firmados expuestos por logs, respuestas de IA, RLS mal configurada, Storage público, capturas, repos o canales de notificación.
- **Probabilidad / impacto / nivel.** Media / Alto / Alto (Ley 81/2019 Panamá).
- **Control preventivo.** (1) Fotos KYC solo en WorkDrive; Supabase guarda referencias (§6). (2) RLS en todas las tablas: clientes solo su `nuc`, afiliados solo su `id_afiliado`; service role solo en servidor. (3) Logs `pino` con `redact` de cédula, cuenta, teléfono; digest a Claude sin datos crudos. (4) Caddy con HSTS, CSP y cabeceras; rate limiting y captcha en lookup de cédula y OTP. (5) Secrets fuera del repo; `.env` 600; `.gitignore` con `.env*`. (6) `/verificar/{uuid}` sin datos sensibles. (7) PII enmascarada en docs, capturas de Playwright y tickets (regla de este brief).
- **Control detectivo.** `audit.audit_events` append-only con cadena de hashes; Supabase advisors (security) en cada brief con migración; revisión de logs por `request_id`; alertas de acceso inusual (muchas lecturas de un mismo usuario); `git grep` de patrones de token/cédula antes de cada commit.
- **Brief.** 01 (hardening, Caddy), 02 (logs), 03 (RLS, auditoría), 04 (auth/OTP), 17 (verificación pública).
- **Responsable.** Gianclaudio. **Estado:** Abierto.

## R05 — Caída de N8N a mitad de flujo
- **Descripción.** N8N se reinicia o falla entre pasos (p. ej. después de crear el préstamo en LoanDisk y antes de escribir en CRM), dejando estados a medias en Supabase, CRM, LoanDisk o BG.
- **Probabilidad / impacto / nivel.** Media / Medio / Medio.
- **Control preventivo.** (1) Toda llamada app→N8N sale de `webhook_outbox` con reintento exponencial; todo webhook entrante se registra en `webhook_inbox` con `idempotency_key` antes de procesar (§8). (2) Workflows idempotentes: cada paso consulta si el efecto ya existe (préstamo con `external_id`, carpeta con nombre, request de Sign por `solicitud_id`) antes de crearlo. (3) El estado en Supabase solo avanza cuando N8N confirma; nunca por optimismo. (4) Lección v1 (02-oct-2026): el **Retry** de N8N reutiliza la salida guardada del nodo anterior, no reprocesa; por eso `webhook_inbox` conserva el payload original de cada evento y el reproceso siempre re-ejecuta el workflow completo con ese payload.
- **Control detectivo.** `/api/health` verifica N8N; panel "salud del sistema" en `/admin` con última ejecución por workflow y cola de fallidos con reintento; alerta WhatsApp al admin si un workflow lleva N minutos sin ejecutar o falla M veces; `mp_reconcile_crm` detecta solicitudes en estados intermedios por más de X horas.
- **Brief.** 01 (health), 03 (outbox/inbox), 08 (primer flujo app→N8N), 19 (salud, reintentos).
- **Responsable.** Gianclaudio. **Estado:** Abierto.

## R06 — Token Zoho vencido
- **Descripción.** Credencial OAuth de Zoho en N8N expira o es revocada (ya ocurrió: nodos WorkDrive devuelven 500 en lugar de 401, §2). Los flujos de carpetas, CRM write-back y Sign se detienen en silencio.
- **Probabilidad / impacto / nivel.** Alta / Medio / Alto.
- **Control preventivo.** (1) Credenciales OAuth gestionadas por N8N con refresh automático; usar la credencial correcta según el workflow (`V8ToVmg60xSjZasl` sin WorkDrive; `lRBD9utZoqJjYHEW` con nodos WorkDrive y *Token Expired Status Code = 500*). (2) Nunca `neverError: true` en nodos de APIs externas. (3) Rotación documentada en runbook (Brief 19).
- **Control detectivo.** `/api/health` hace una llamada ligera a CRM con la credencial de N8N y alerta por WhatsApp; panel "tokens próximos a vencer"; errores 401/500 de Zoho caen en `webhook_outbox` con reintento y alerta tras 3 fallos.
- **Brief.** 01 (health), 19 (salud y runbook).
- **Responsable.** Gianclaudio. **Estado:** Abierto.

## R07 — Discrepancia Supabase ↔ CRM
- **Descripción.** El estado operativo en Supabase y el expediente en CRM divergen (write-back fallido, edición manual en CRM, tasa cambiada en CRM sin espejo).
- **Probabilidad / impacto / nivel.** Media / Medio / Medio.
- **Control preventivo.** (1) Toda transición escribe en CRM vía outbox; la app nunca escribe la tasa, solo la espeja desde CRM (`Afiliados.Taza_de_Interes`, §4.4). (2) Regla no negociable: si difieren, gana CRM (§3). (3) Snapshot por solicitud: los cambios posteriores de parámetros no alteran préstamos ya otorgados.
- **Control detectivo.** `mp_reconcile_crm` nocturno compara campos clave (estado, tasa, montos, IDs de Sign/WorkDrive/LoanDisk), corrige Supabase y escribe la discrepancia en `audit_events`; alerta si las discrepancias superan un umbral o afectan solicitudes activas.
- **Brief.** 05 (espejo CRM→Supabase), 08 (write-back), 19 (reconciliación).
- **Responsable.** Gianclaudio. **Estado:** Abierto.

## R08 — Desembolso accidental por pruebas contra BG LIVE
- **Descripción.** Una prueba (unitaria, e2e, ejecución manual de N8N, demo en staging) llega al 06 prod `GTFFlEfXa0LOTtnF` o al ambiente BG de producción y genera una transferencia real pendiente.
- **Probabilidad / impacto / nivel.** Media / Alto / Alto.
- **Control preventivo.** (1) `bg_ambiente` = `qa` por defecto en todo entorno que no sea producción; el valor `prod` solo existe en el `.env` del contenedor de producción y requiere aprobación explícita de Gianclaudio y Diego (CLAUDE.md). (2) `lib/banking` con `dry_run = true` por defecto en staging y en tests; el adaptador se niega a llamar a BG si `NODE_ENV != production` y `bg_ambiente = prod`. (3) 06 QA `EQOqUBQp1N60zFlG` (ambiente `bg-h2h-qa2`, cuenta de certificación) es el único destino de pruebas. (4) Nunca `execute_workflow`/`test_workflow`/`prepare_workflow_pin_data` sobre el 06 prod; nunca modificarlo. (5) Préstamos de prueba sin numeración SO ni secuencial (§18).
- **Control detectivo.** `bg_transacciones` registra el ambiente de cada envío; alerta inmediata si llega un envío con `prod` desde un host de staging; Diego ve en Banca en Línea cualquier transferencia pendiente inesperada y la rechaza (el 06 prod no ejecuta, solo deja pendiente); revisión semanal de `search_workflow_executions` del 06 prod.
- **Brief.** 00 (política), 05 (adaptador `dry_run`), 12 (desembolso).
- **Responsable.** Gianclaudio (técnico), Diego (aprobación en banca). **Estado:** Política definida; controles técnicos pendientes.

## R09 — Parámetro financiero mal configurado por un usuario
- **Descripción.** Un usuario de `/admin` guarda una tasa, plazo, monto, fee o % de descuento erróneo (p. ej. 24 en lugar de 2.4, o un plazo no soportado por LoanDisk) y se emiten documentos y préstamos con esos valores.
- **Probabilidad / impacto / nivel.** Media / Alto / Alto.
- **Control preventivo.** (1) Edición solo con permiso `parametros.editar` + OTP en el momento (§4.5). (2) Validación de rangos: tasa dentro del min/max del producto LoanDisk (383523: 18–30 % según §18; ajustable), plazos dentro de la lista permitida, montos > 0, ciclos con esquema LoanDisk configurado. (3) Previsualización de la letra y del total con un ejemplo antes de guardar; vigencia "desde" obligatoria. (4) Snapshot congela los parámetros al enviar la solicitud; un cambio no afecta solicitudes ya enviadas. (5) Tasa del afiliado con una sola fuente (CRM).
- **Control detectivo.** `parametros_hist` con antes/después, usuario y fecha; notificación a gerencia y contabilidad por cada cambio; `mp_digest_diario` lista cambios de parámetros; comparación `loan_interest` enviado a LoanDisk vs `Taza_de_Interes` en CRM en `mp_loandisk_crear`; reconciliación del snapshot con el calendario de LoanDisk después de crear el préstamo.
- **Brief.** 04 (OTP), 06 (validaciones y tests), 09 (pantalla de parámetros).
- **Responsable.** Diego (dueño de parámetros), Gianclaudio (controles). **Estado:** Abierto.

## R10 — Supabase en plan Free: pausa por inactividad y sin backups diarios
- **Descripción.** El proyecto `isthmus-mp` aún no existe; la organización está en plan Free (upgrade a Pro pendiente). En Free el proyecto se pausa tras inactividad y no hay backups diarios ni PITR: una pausa deja la app caída y una corrupción pierde datos.
- **Probabilidad / impacto / nivel.** Alta / Alto / **Crítico**.
- **Control preventivo.** Upgrade a Pro **antes** de crear el proyecto (Brief 03 no arranca sin él); backups diarios verificados y restauración probada en staging (Brief 01, criterio de aceptación); `docker volumes` del VPS respaldados a almacenamiento externo con retención 14 días.
- **Control detectivo.** `/api/health` detecta DB no disponible y alerta; verificación mensual de que el backup más reciente restaura.
- **Brief.** 01 (backups), 03 (creación del proyecto en Pro).
- **Responsable.** Gianclaudio. **Estado:** **Bloqueante** para Brief 03 y para producción.

## R11 — Repo sin remoto: un fallo del VPS pierde el código
- **Descripción.** `mp-app` vive solo en `/opt/mp-app` del VPS (sin `git remote`). Un fallo de disco, un `rm` equivocado o la pérdida del servidor borra el código y los documentos del proyecto.
- **Probabilidad / impacto / nivel.** Alta / Alto / **Crítico**.
- **Control preventivo.** Remoto privado (GitHub/GitLab) con push después de cada brief, o como mínimo copia off-site del repo dentro del backup diario del Brief 01. El MCP de GitHub de esta sesión falló al conectar; la decisión y las credenciales son de Gianclaudio.
- **Control detectivo.** Verificación de backups con restauración probada (Brief 01); alerta si el push o el backup fallan.
- **Brief.** 00 (decisión), 01 (backups).
- **Responsable.** Gianclaudio. **Estado:** **Pendiente**.

## R12 — Sesión de Claude Code con acceso a N8N que contiene BG LIVE
- **Descripción.** El MCP de N8N conectado a esta sesión puede ejecutar, modificar o publicar workflows, incluido el 06 prod. Un error del agente o una instrucción ambigua puede disparar una transferencia real o romper un flujo en producción.
- **Probabilidad / impacto / nivel.** Media / Alto / Alto.
- **Control preventivo.** (1) Allowlist vigente para inventario y briefs de lectura: solo `get_workflow_details`, `list_credentials`, `search_workflows`, `search_workflow_executions`, `get_workflow_execution`. Prohibido `execute_workflow`, `test_workflow`, `prepare_workflow_pin_data`, `update_workflow`, `publish_workflow`, `unpublish_workflow`, `archive_workflow` (instrucción de Gianclaudio, 02-oct-2026). (2) CLAUDE.md: todo cambio a N8N se muestra antes y requiere aprobación; nunca el 06 prod. (3) Recomendación: credencial/API key de N8N para el MCP con permisos mínimos y, cuando N8N lo permita, proyecto separado para MP sin acceso al 06 prod. (4) El clasificador de permisos de Claude Code bloquea lecturas directas a la BD de N8N (comprobado en este brief).
- **Control detectivo.** `get_workflow_history` / `activeVersionId` del 06 prod revisado al cierre de cada sesión que tocó N8N; `search_workflow_executions` del 06 prod sin ejecuciones no esperadas; Diego rechaza en banca cualquier transferencia pendiente no solicitada.
- **Brief.** 00 (política documentada), 12 (cuando la app empiece a llamar a BG).
- **Responsable.** Gianclaudio. **Estado:** Mitigado parcialmente.

---

## Riesgos detectados en el inventario (Brief 00)

| # | Hallazgo | Riesgo | Control / acción | Brief |
|---|---|---|---|---|
| R13 | Los templates de Sign **Contrato** y **Carta de Descuento** aún tienen un firmante `Isthmus` tipo `APPROVER` (Gisela) en el orden 2, y la Carta tiene 3 pasos (Solicitante → Isthmus → RRHH). §13.2 dice que no hay aprobador en Sign. | Un sobre único (`mergesend`) hereda el aprobador y bloquea la firma de RRHH hasta que Gisela aprueba; discrepancia con la decisión cerrada. | Brief 10 valida en sandbox el sobre único con los 4 templates y decide con Diego si se elimina el paso APPROVER de los templates (cambio en Zoho Sign, requiere aprobación). | 10 |
| R14 | `Solicitudes_Microprestamo.Cuotas` es picklist con valores `6` y `9`; no existe `12`, `18` ni `24`. `Monto_Solicitado` es picklist `100/150/200/300`. | Si CRM sigue como expediente, los plazos 6/9/12 meses y montos nuevos no caben en el picklist; el write-back fallaría. | Brief 05/09: ampliar picklists en CRM (cambio aprobado) o escribir el valor en campo numérico nuevo. Nunca hardcodear la lista en la app. | 05, 09 |
| R15 | LoanDisk: el ciclo `Bimonthly` (ID 12) genera cuotas cada 2 meses por API (§18). | Préstamo con calendario incorrecto. | `parametros` solo admite esquemas `4646` (10-25) y `4418` (15-30); test en Brief 06/11 rechaza cualquier otro ID. | 06, 11 |
| R16 | El callback de IDAnalyzer llega normalmente **antes** de que exista la solicitud (orden real del cliente: WhatsApp → KYC → formulario). En la v1 el WhatsApp con el enlace dependía de encontrar la solicitud y casi nunca salía. | KYC perdido, enlace nunca enviado o KYC asociado a la solicitud equivocada. | **Control ya implementado en v1** (03 KYC corregido y publicado el 02-oct-2026, pendiente de validación en vivo): WhatsApp inmediato al aprobar IDAnalyzer sin depender de la solicitud (su fallo no frena el resto); búsqueda por cédula con reintentos cada 2 min × 15; a los 30 min correo desde gestionprestamos@ a Gisela y Gianclaudio con el enlace de la ejecución. La app replica: OTP/enlace independiente de la solicitud; `mp_kyc_callback` guarda el payload original en `webhook_inbox`, reintenta la asociación y alerta a operaciones. | 03, 04, 07 |
| R17 | Préstamos de prueba en LoanDisk con numeración SO bloquean préstamos reales: volvió a ocurrir el 02-oct-2026 (un préstamo manual "SO -00079" bloqueó el real de SO-00079). | Colisión de referencias en producción; desembolso retrasado. | Regla reconfirmada: pruebas manuales sin `SO-` ni numeración en secuencia; prefijo `TEST-` y branch de pruebas; la app valida que `Prestamo_No` no esté ya usado antes de escribirlo en CRM. | 11 |
| R18 | Los webhooks CRM→Zoho Flow ("Crear Carpetas" de `Afiliados` y `Solicitudes_Microprestamo`) llevan un `zapikey` en la URL, visible a quien tenga acceso de lectura a la configuración de CRM. | Secreto expuesto en metadatos; no se copia a ningún documento. | Al retirar Zoho Flow (Brief 08 y 19) eliminar las reglas y webhooks; mientras tanto, no documentar la URL completa. | 08, 19 |
| R19 | `getFields` devuelve picklists incompletos: en registros reales aparecen `Estado_Solicitud = Cancelada` y `Canal_de_Entrada = Formulario Web (Creator)`, ausentes en la metadata. | La máquina de estados y el espejo CRM podrían rechazar valores reales. | Brief 03/05: construir el mapeo de estados a partir de los valores observados + layout, no solo de `getFields`; tolerar valores desconocidos registrándolos en auditoría. | 03, 05 |
| R20 | `Afiliados.Frecuencia_de_Planilla` incluye `Semanal`, sin esquema LoanDisk ni regla de inicio de descuento. | Solicitud de un afiliado semanal se detiene en `desembolso_pendiente`. | La app modela solo `15-30` y `10-25` (§4.6); `Semanal` queda deshabilitado y alerta al admin. | 05, 06 |
| R21 | CRM `Afiliados` no tiene `Modo_Validacion`; `Estado` del afiliado está vacío en los dos registros; `Loan_Product`, `Number_of_Payments`, `Repayment_Cycle` existen pero vacíos. | Camino B y el estado activo del afiliado no tienen fuente en CRM; campos LoanDisk sin uso confunden. | Brief 05: crear `Modo_Validacion` en CRM (cambio aprobado por Diego) y espejarlo; definir `Estado` como fuente del "afiliado activo"; documentar que los IDs de LoanDisk viven en `parametros`, no en esos campos. | 05 |
| R22 | El MCP de N8N requiere re-autenticación y el inventario de workflows (04, 05 v2, 06 prod/QA, payload BG, IDs LoanDisk desde los nodos) no pudo completarse en este brief. | Briefs 11 y 12 arrancarían sin la estructura real del payload BG ni los IDs tal como viajan hoy. | Gianclaudio re-autentica el conector n8n en claude.ai; completar la sección N8N de `docs/INVENTARIO_ACTUAL.md` antes del Brief 05. | 00 (pendiente), 05 |
