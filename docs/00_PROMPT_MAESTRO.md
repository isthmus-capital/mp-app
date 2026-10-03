# PROMPT MAESTRO — App Micropréstamos Isthmus Capital (FIC)
<!-- Paquete: v5 — 01-oct-2026 -->

> Uso: pegar este documento como `docs/00_PROMPT_MAESTRO.md` en el repo y referenciarlo desde `CLAUDE.md`. Claude Code debe leerlo completo antes del Brief 01.
> Idioma del producto: español (Panamá). Idioma del código/commits: inglés.
> **Versión 5.4 — 3 oct 2026 (tarde):** §19.10 cerrado por Diego: durante la convivencia con la v1 la tasa se edita solo en CRM y la app la lee; al apagar la v1 se edita en `/admin` con write-back a Zoho en un campo que no dispare el contrato del afiliado; la tasa se congela al enviar la solicitud y se respeta aunque cambie en revisión (aviso informativo al aprobador, sin bloqueo); AF-0031 es un afiliado de prueba. §19.14: lectura de CRM en solo lectura (una regla `create`, nada sobre la tasa). §4.3, §4.4, §8, §12 y §16.2 alineados; R41 y R42 actualizados con la propuesta de disparador vacío → lleno y plan de prueba en AF-0033.
> **Versión 5.3 — 3 oct 2026:** decisiones de Diego del 02-oct en §19.10–19.13: historial de tasas por afiliado append-only (valor, vigencia, usuario, motivo), tasa congelada por préstamo al aprobarse, cambio solo por `admin` validado contra el rango del producto LoanDisk; productos configurables y versionados con catálogo fijo de pasos (esquema multi-producto desde el Brief 03, lanzamiento con un solo producto, pantalla de productos en el Brief 20); riesgos R41–R43; marca MP en §1, §4.1, §12 y Brief 02 (FIC solo como respaldo).
> **Versión 5.2 — 2 oct 2026:** §19: la solicitud nace en `borrador` en el paso 1 del wizard y la sesión KYC se asocia a ella; wizard reanudable con OTP; IDAnalyzer redirige al formulario al aprobar (el WhatsApp con el enlace es respaldo); sesión de diseño con Gianclaudio (5 pantallas HTML con tokens FIC al cierre del Brief 01); reglas de calidad de UI; remoto GitHub privado con push tras cada commit.
> **Versión 5.1 — 2 oct 2026:** §4.6-a: `total_pagar` = capital + interés flat; cuota redondeada a centavos con ajuste en la última cuota; alerta si LoanDisk difiere (decisión de Gianclaudio, Brief 00).
> **Versión 5 — 1 oct 2026:** incorpora lo aprendido al poner en producción la v1 Zoho + N8N (§18): producto y ciclos de LoanDisk, sobre único de Sign, ambiente QA de BG, remitente de correos.
> **Versión 4 — 29 sep 2026:** reglas financieras de la v1 formalizadas (§4.6): inicio de descuento por ciclo de planilla (afiliados con uno o dos ciclos), cuota quincenal para 3/6/9/12 meses, plantilla descargable de Base Diaria.
> **Versión 3 — 28 sep 2026:** parametrización total (§4.4), usuarios y permisos (§4.5), plantilla WhatsApp aprobada (§14), convenio de afiliación firmado en físico, BG en producción.
> **Versión 2 — 20 sep 2026.** Incluye: retiro de Zoho Flow y Creator, Camino B (afiliado sin Base Diaria), abstracción `kyc_provider`, contratos de datos del ANEXO A del Convenio, identidad visual FIC y calendario comprimido de 3 semanas.

---

## 0. Rol y forma de trabajo

Eres el arquitecto y desarrollador principal de una plataforma fintech de micropréstamos por descuento directo para **Financiera Isthmus Capital (FIC), Panamá**. Trabajas en VS Code + Claude Code con Remote-SSH al VPS. Construyes por **briefs numerados** en `docs/briefs/`, uno a la vez, con `git commit` entre briefs y prueba real antes de avanzar. Cambios en fórmulas financieras, desembolsos, firmas y endpoints de producción van en **modo aprobación manual**; cambios aditivos/cosméticos en auto.

Antes de escribir código en cualquier brief:
1. Lee `CLAUDE.md`, este documento y el brief activo.
2. Usa los MCP conectados para verificar el estado real (nombres de campos API de Zoho, columnas Supabase, nodos N8N) — nunca asumas que lo visible en la UI coincide con el API name.
3. Si un dato de negocio no está en este documento, pregunta; no lo inventes.

---

## 1. Contexto de negocio

- **Producto:** micropréstamos a **colaboradores de empresas afiliadas** (Afiliados). El pago se hace por **descuento directo de planilla**; el Afiliado (RRHH) retiene y remite a FIC.
- **Elegibilidad:** el solicitante debe existir en la **Base Master de Empleados** (alimentada por los archivos "Base Diaria" que sube cada Afiliado). Las condiciones de aprobación/rechazo (antigüedad ≥ 3 meses, descuentos actuales ≤ 50 % del salario bruto, capacidad de pago, validación de cuenta bancaria por banco, etc.) hoy viven en el formulario de Zoho Creator y son **independientes** del KYC de IDAnalyzer.
- **Trazabilidad:** ya existe un **Número Único de Cliente** (NUC). Es la llave de todo: CRM, WorkDrive, Supabase, LoanDisk, BG, notificaciones. Nunca se crea un cliente sin NUC ni dos NUC para la misma cédula.
- **Objetivo del rediseño:** que el cliente viva una experiencia **profesional, seria, con la marca MP Micropréstamos** (app instalable en teléfono; FIC como respaldo, §19.9), con un proceso más fluido, un solo correo con los 4 documentos, y un back-office administrable — manteniendo **Zoho CRM como repositorio del expediente** de clientes y afiliados.

---

## 2. Stack e infraestructura (ya existente — reutilizar)

| Capa | Herramienta | Notas |
|---|---|---|
| VPS | Hetzner CPX31 `5.78.214.136`, Ubuntu, Docker Compose + Caddy | Hoy corre como root → **Brief 01 crea usuario no-root + hardening** |
| Orquestación | N8N self-hosted `automation.isthmuscap.com` | Regla: `update_workflow` + `publish_workflow` siempre; verificar `activeVersionId` |
| Apps existentes | Next.js 14 + TS: Cotizador (3001), Max Motors (3002) | La nueva app MP va en **puerto 3003**, mismo patrón Docker |
| DB app | Supabase **Pro**, proyecto `isthmus-mp` (ref `waqvypbjicddmknwerip`, us-west-2 Oregon junto al VPS, compute Micro, Postgres 17; creado el 02-oct-2026, §19.8) | Postgres + Auth + RLS + Storage temporal. RLS automática en tablas nuevas y **"expose new tables" desactivado**: cada tabla necesita `GRANT` explícito para `anon`/`authenticated` (§7) |
| Expediente | Zoho CRM módulos `Afiliados`, `Solicitudes_Microprestamo` (+ `Contacts`) | Repositorio maestro del expediente |
| Documentos | Zoho WorkDrive (Team Folder **General** → `Microprestamos/Afiliados/…`) | Flow solo accede al Team Folder "General" |
| Firma | Zoho Sign (templates Contrato `561993000000057083`, Pagaré `…058038`, Carta `…058099`, APC `…058138`) | Webhook Sign → N8N |
| Base empleados | ~~Zoho Creator~~ → **Supabase `empleados_master`** | Creator y Zoho Flow **se retiran** (visto bueno de Diego, §4.3). Se mantienen solo en modo lectura durante el piloto |
| KYC | IDAnalyzer DocuPass, profile `53067a87b10a41bd8771c34e9b7c53c4` | **Siempre detrás de la interfaz `kyc_provider`** (§6-bis). Callback guarda `IDAnalyzer_Session_ID` |
| Core de préstamos | LoanDisk (Public Key 75055, Branch 87572) | Borrower + Loan + repayments |
| Desembolso | Banco General Conexión BG H2H (`conexionbg.bgeneral.cloud`, cuenta origen `0301000001265`) | **Flujo N8N ya en producción (usado desde Monday)**; ahora **un solo firmante/aprobador** |
| PDF | Gotenberg (contenedor en red `n8n_default`) | Cartas de saldo, recibos, estados de cuenta |
| Correo | SMTP Google Workspace `gestionprestamos@isthmuscap.com` | Notificaciones MP |
| WhatsApp | Meta Cloud API (número dedicado MP) / SalesIQ | Confirmaciones y links |
| IA | Claude API (Haiku para extracción/validación de CSV, Sonnet para resúmenes de expediente) | Nunca datos crudos; digest compacto |

Credenciales N8N a respetar: Zoho `V8ToVmg60xSjZasl` para workflows sin WorkDrive, `lRBD9utZoqJjYHEW` solo cuando hay nodos WorkDrive (Token Expired Status Code = 500). Nunca `neverError: true` en nodos que llaman APIs externas.

---

## 3. Arquitectura objetivo

```
                ┌─────────────────────────────────────────────┐
                │        mp.isthmuscap.com  (Next.js 14 PWA)   │
                │  /cliente   /afiliado   /admin   /api/*      │
                └───────┬───────────────┬──────────────┬───────┘
                        │               │              │
                 Supabase (isthmus-mp)  │      N8N (orquestación)
                 auth · estado · audit  │       │   │   │   │   │
                        │               │   CRM WD  Sign LD  BG  IDAnalyzer
                        └───── sync ────┴───────┴───┴────┴───┴───┘
```

**Principio de fuentes de verdad (no negociable):**
- **Supabase** = estado operativo en tiempo real de la solicitud, sesiones, auditoría, colas. La app **nunca** lee Zoho en el request path del cliente (latencia y cuotas).
- **Zoho CRM** = expediente oficial (cliente, afiliado, solicitud, IDs de documentos, historial). Toda transición de estado se **escribe también** en CRM (write-back) vía N8N.
- **WorkDrive** = archivos finales (KYC, formulario PDF, firmados, desembolso).
- **LoanDisk** = saldos, cuotas, pagos. Es la fuente para estados de cuenta; se cachea en Supabase (`loan_snapshots`) con refresco programado + bajo demanda.
- Si Supabase y CRM difieren, gana **CRM**; el job `reconcile_crm` corrige Supabase y registra la discrepancia en auditoría.

**Regla de arquitectura:** SQL hace la aritmética determinista; Claude interpreta/resume; N8N mueve datos entre sistemas; Next.js muestra y captura. Nada de lógica financiera en el frontend.

---

## 4. Módulos funcionales

### 4.1 Portal Cliente (`/cliente`) — PWA instalable

Marca MP Micropréstamos (`public/brand/mp-logo.png`, tokens `--mp-*`; paleta sobria, tipografía seria; sin gradientes llamativos; FIC como respaldo en inicio de sesión y pie, §15 y §19.9). Manifest + service worker (`next-pwa`), "Agregar a pantalla de inicio" con instrucciones iOS/Android. Fase 2 opcional: Capacitor para tiendas.

**Onboarding / Solicitud (wizard de 6 pasos, guardado automático, reanudable con OTP — §19. La solicitud se crea en `borrador` en el paso 1 y todo lo demás, incluida la sesión KYC, cuelga de ella)**
1. **Cédula** → lookup en Base Master → muestra empresa, fecha ingreso (enmascarado). Si no existe: mensaje "tu empresa aún no ha enviado tu registro" + botón "Avisar a mi RRHH" (envía correo al contacto del afiliado).
2. **Verificación de identidad** → IDAnalyzer DocuPass por redirect, con la sesión KYC asociada a la solicitud en `borrador`; al aprobar, IDAnalyzer **redirige al wizard** (el WhatsApp con el enlace es solo respaldo, §19); callback guarda `session_id`, resultado, score y fotos en `01_KYC`. Selfie con instrucción visual (ya existe imagen en `isthmuscap.com/img/…`).
3. **Datos de la solicitud** → monto y plazo (botones con los valores parametrizados del afiliado, §4.4), ciclo de planilla si su empresa tiene más de uno (o viene de la base), cuenta bancaria (validación por banco), servicios públicos, etc. Ve su fecha de primer descuento, la cuota quincenal y el total a pagar. Cálculo de letra en servidor (`/api/quote`) usando la tasa vigente del Afiliado. Pre-evaluación en vivo: antigüedad, 50 % descuentos, capacidad. Rechazo automático explicado con cortesía y opción de "solicitar revisión".
4. **Términos y condiciones** dinámicos (HTML generado desde parámetros) + aceptación con timestamp, IP y user-agent (evidencia).
5. **Resumen y envío** → crea/actualiza NUC, `Solicitudes_Microprestamo` en CRM (vía N8N), carpetas WorkDrive (`01_KYC … 06_Desembolso`), PDF del formulario a `02_Formulario`.
6. **Seguimiento** → timeline visual: Recibida → En revisión → Aprobada → Documentos enviados → Firmados → Desembolsado. Push/WhatsApp/email en cada cambio.

**Post-desembolso (self-service)**
- **Estado de cuenta** (LoanDisk): saldo, próxima cuota, cuotas pagadas/pendientes, mora si aplica. El PDF replica el **Cronograma de Pagos** que hoy emite LoanDisk (encabezado FIC, datos del préstamo, tabla capital/interés/comisiones/penalidad/balance, pie legal).
- **Historial de pagos** con recibo PDF por pago (Gotenberg, numerado `MP-REC-00001`).
- **Carta de saldo / Paz y salvo**: solicitud → generación automática PDF con firma digital de FIC y código QR de verificación (`/verificar/{uuid}`) → guardada en `06_Desembolso`/WorkDrive y en `documentos_cliente`. Si requiere aprobación (paz y salvo), pasa por cola admin.
- **Mis documentos**: los 4 firmados + certificados de Sign, descargables.
- **Nueva solicitud / refinanciamiento**: reutiliza KYC vigente (< 12 meses) y datos; solo actualiza lo que cambió.
- **Perfil y seguridad**: OTP por WhatsApp/SMS o magic link (sin contraseñas). Cambio de correo/teléfono requiere OTP al canal anterior.

### 4.2 Portal Afiliado (`/afiliado`) — RRHH de la empresa

- Login corporativo (magic link al correo registrado en CRM `Afiliados`). Un afiliado puede tener varios usuarios (RRHH, Finanzas).
- **Carga de Base Diaria** (drag & drop CSV/XLSX). Requisito de Gisela: el afiliado **descarga la plantilla desde la app** (`Descargar plantilla`, XLSX con las 15 columnas del ANEXO A más `ciclo_planilla`, encabezados fijos, columnas de código y teléfono en formato texto para no perder ceros, fechas `AAAA-MM-DD` con validación de celda, listas desplegables en `estatus_laboral`, `tipo_contrato` y `ciclo_planilla`, fila de ejemplo y hoja de instrucciones). Solo la llena y la sube; la app rechaza archivos con otros encabezados y dice cuál falta. La plantilla se genera desde el mismo contrato de datos: si cambia una columna, cambia en la app, en la plantilla y en la validación a la vez:
  1. Se sube a Supabase Storage (`staging/{id_afiliado}/{fecha}.csv`).
  2. N8N `mp_base_diaria_ingest`: detecta BOM, mapea columnas dinámicamente por header (15 columnas del template), normaliza fechas (`M/D/YYYY` y `YYYY-MM-DD`), limpia montos, valida cédula panameña, detecta duplicados y cambios de salario > 30 % (alerta).
  3. Genera **reporte de validación** visible en el portal (aceptadas / rechazadas / advertencias por fila) antes de aplicar.
  4. RRHH confirma → upsert en `empleados_master` (Supabase) por `cedula + id_afiliado` **y** copia el archivo a WorkDrive `Base Diaria` del afiliado (compatibilidad con el proceso Zoho actual, ver §4.3).
  5. Marca como *inactivos* (no borra) a los empleados que dejaron de aparecer N cargas consecutivas → alerta de riesgo si tienen préstamo activo.
- **Solicitudes de sus colaboradores**: lista, estado, monto; **firma de Carta de Descuento** (Zoho Sign, rol firmante RRHH) desde el portal.
- **Remesas de descuento**: cada quincena/mes, la app genera el archivo de descuentos a retener (desde LoanDisk) para que RRHH lo aplique en planilla; RRHH sube comprobante de la transferencia consolidada; conciliación automática contra pagos en LoanDisk (Brief tardío).
- **Convenio de afiliación** (Writer → firmado en físico → escaneado en WorkDrive): visible/descargable; estado `Estado_del_Contrato`.

### 4.3 Alta de Afiliados y Base Master — **Flow y Creator se retiran**

**Proceso actual (referencia, se apaga al terminar el piloto):** Zoho Forms → CRM `Afiliados` → analista coloca la **tasa manualmente** → Zoho Flow "Crear Carpetas Afiliado" → WorkDrive `AF-XXXX/{Base Diaria, Contrato Afiliado, Solicitudes}` → el afiliado sube CSV a `Base Diaria` → Deluge `procesarCSVEnCreator` hace upsert en Creator `Empleados` → el formulario Creator valida cédula contra `Empleados_Report`.

**Proceso objetivo (Opción B, aprobada):**
1. Alta del afiliado desde `mp.isthmuscap.com/afiliarse` o `/admin/afiliados` → escribe en **CRM `Afiliados`** (sigue siendo el expediente).
2. Diego coloca la **tasa** (sigue siendo el trigger). El cambio lo detecta **N8N** (regla de CRM `field_update` sobre `Taza_de_Interes` que dispara **solo cuando la tasa pasa de vacío a lleno**, con `WorkDrive_Folder_ID` vacío como criterio de idempotencia; propuesta en R42, §19.14), **no Zoho Flow**: crea las carpetas WorkDrive, guarda los IDs en CRM, genera el convenio de afiliación (Zoho Writer) y avisa a Diego. **El convenio se imprime y se firma en físico** (decisión de Diego; no pasa por Sign). El escaneado firmado se sube desde `/admin/afiliados` a la carpeta `Contrato Afiliado` y marca `Estado_del_Contrato = Firmado`; solo entonces el afiliado queda activo.
3. Carga de la Base Diaria por el **Portal Afiliado** (§4.2) → validación → `empleados_master` en Supabase → copia del archivo a WorkDrive `Base Diaria` como histórico.
4. El formulario Creator se apaga cuando el wizard del cliente esté en producción (Brief 19).

Beneficios: errores visibles al instante para RRHH; lookup en Postgres sin límites de API; historial versionado de qué salario/deducción se usó en cada aprobación; alertas automáticas; un solo orquestador (N8N) con logs en un lugar; menos Deluge que mantener.

### 4.3-bis Camino B — afiliado sin Base Diaria

Diego habilitó un segundo modo de elegibilidad para afiliados de alta confianza. Es un **campo por afiliado**, no una bifurcación del sistema: CRM `Afiliados` → `Modo_Validacion` ∈ {`base_diaria`, `declaracion_rrhh`}, espejado en Supabase.

| | `base_diaria` (default) | `declaracion_rrhh` (Camino B) |
|---|---|---|
| Origen de los datos laborales | `empleados_master` | Los declara el solicitante en el wizard |
| Si la cédula no existe | No avanza | No aplica: elige su empresa de la lista o entra por link/código del afiliado |
| Aval | El archivo cargado por RRHH | **RRHH confirma los datos desde `/afiliado`** antes de que el analista apruebe (un clic; queda en auditoría con usuario, fecha e IP) |
| Fase 1 (carga de base) | Sí | No existe |

Todo lo demás es idéntico: mismo KYC, mismas reglas (antigüedad ≥ 3 meses, descuentos ≤ 50 %/20 % según convenio, capacidad), mismos 4 documentos, misma carta de descuento firmada por RRHH, mismo desembolso. El afiliado piloto del Camino B se define en el momento de la prueba (Diego).

### 4.3-ter Contratos de datos — ANEXO A del Convenio

El ANEXO A del Convenio de Afiliación ya fija los intercambios de datos con el afiliado; el esquema Supabase y el portal los implementan tal cual:

- **Base de empleados** (carga del afiliado): `employee_id, cedula, nombre_completo, fecha_nacimiento, fecha_ingreso, salario_bruto, salario_neto, tipo_contrato, estatus_laboral, departamento, cargo, email, telefono, descuentos_actuales, fecha_actualizacion`. Obligatorios: `employee_id, cedula, nombre_completo, fecha_ingreso, salario_neto, estatus_laboral, email, fecha_actualizacion`.
- **Reporte de préstamos a RRHH** (FIC → afiliado): `loan_id, employee_id, cedula, nombre_completo, monto_prestamo, cuota_mensual, tasa_interes, tipo_prestamo, plazo_meses, fecha_aprobacion, fecha_inicio_descuento, fecha_fin, estatus_prestamo, fecha_desembolso`.
- **Conciliación** (afiliado → FIC): `loan_id, employee_id, cuota_esperada, cuota_recibida, diferencia, estatus, dias_atraso`.
- **Novedades laborales** (afiliado → FIC): `employee_id, cedula, nombre_completo, estatus_laboral, fecha_cambio, tipo_evento, motivo, ultima_fecha_pago, saldo_prestamo, observaciones`. Una novedad de cese/suspensión con préstamo activo genera **alerta inmediata** a FIC.
- Parámetros del convenio por afiliado: **comisión 4 %** sobre el monto bruto desembolsado (liquidación mensual contra reporte validado), **% máximo de descuento**, **tasa** (la del ANEXO es plantilla; la real se coloca por afiliado), **SLA de desembolso** (24/48 h) y **días de transferencia**. Todos viven en `afiliados` y son administrables.

### 4.4 Parametrización — nada financiero fijo en el código

Requisito de Diego: todo lo que define el producto se cambia desde `/admin`, sin tocar código. Tres niveles; el más específico gana: **afiliado → producto → global**.

| Parámetro | Nivel | Ejemplo inicial | Viaja a |
|---|---|---|---|
| Plazos permitidos (meses) | producto, sobrescribible por afiliado | 3, 6, 9, 12 — **solo 3 habilitado al inicio** | LoanDisk (`loan_duration`, nº de cuotas = meses × 2) |
| Ciclos de planilla del afiliado | afiliado | `15-30`, `10-25` o **ambos** | Regla de inicio de descuento (§4.6) y esquema LoanDisk por ciclo (`15-30` → 4418; `10-25` → pendiente que Gisela lo cree) |
| Montos ofrecidos | producto / afiliado | 100, 150, 200, 300 | Wizard (botones) + LoanDisk (`loan_principal_amount`) |
| Tasa de interés | **afiliado** (obligatoria, puede cambiar; aplica a solicitudes nuevas; historial append-only; congelada al enviar la solicitud, §19.10) | la que coloca Diego en CRM `Taza_de_Interes` | Documentos (nominal = efectiva) y LoanDisk (`loan_interest`, validada contra el rango del producto antes de guardar, §19.10) |
| Método de interés | producto | Flat mensual (16 %/mes en el préstamo 16860) | LoanDisk |
| % máximo de descuento | afiliado | 20 % (ANEXO A) | Motor de reglas |
| Antigüedad mínima | producto / afiliado | 3 meses | Motor de reglas |
| Modo de validación | afiliado | `base_diaria` / `declaracion_rrhh` | Wizard |
| Comisión al afiliado | afiliado (`Tasa_de_Comisi_n`, puede cambiar; mismo historial append-only que la tasa, §19.10) | 4 % del bruto desembolsado | Convenio (Anexo A) y liquidación mensual |
| FECI, comisión de cierre, timbres, seguro | producto | los del flujo vigente (Brief 00 los extrae) | LoanDisk (fees) |
| SLA de desembolso, días de transferencia | afiliado | 24/48 h | Alertas y recordatorios |
| Textos legales, plantillas de mensajes | global, versionados | T&C y APC actuales | Wizard, Sign, WhatsApp, email |

Reglas de implementación:
- Tablas `productos`, `parametros_afiliado`, `parametros_producto`, `parametros_hist` (quién, cuándo, antes/después, vigencia desde). Una solicitud **congela** los parámetros vigentes al enviarse (`evaluaciones.snapshot`); cambios posteriores no afectan préstamos ya otorgados. **Precisión 02-oct-2026 (§19.11):** `productos` nace multi-producto y versionado en el Brief 03 (el lanzamiento usa solo el producto MP, versión 1) y la solicitud congela también la versión del producto.
- La **tasa del afiliado** tiene una sola fuente: CRM `Afiliados.Taza_de_Interes`. N8N la espeja a Supabase al cambiar; la app nunca la escribe por su cuenta. El Brief 00 verifica cómo viaja hoy de Zoho a LoanDisk en el flujo vigente y se replica ese mismo camino. **Precisión 02-oct-2026 (§19.10):** la tasa y la comisión llevan historial append-only por afiliado (valor, vigencia desde, usuario, motivo); durante la convivencia con la v1 se editan **solo en CRM** y la app las lee por el espejo; al apagar la v1 (Brief 19) se editan en `/admin` (solo `admin`, validación contra el rango del producto LoanDisk antes de guardar) y N8N las escribe en Zoho en un campo que no dispare el contrato del afiliado (§19.10, R42).
- Los IDs de LoanDisk (producto, esquema de pago, desembolsado por) se guardan como parámetros de producto, no en el código.
- El cálculo de la letra en `/api/quote` lee exclusivamente estos parámetros y se prueba contra el préstamo 16860 (300.00, 16 %/mes, quincenal, 5 cuotas, total 420.00).

### 4.5 Usuarios y permisos

Un solo sistema de usuarios (Supabase Auth) con roles y alcance. Todo se administra desde `/admin/usuarios`; alta, baja y cambios de rol quedan en auditoría.

**Internos (FIC)** — acceso por correo `@isthmuscap.com` + OTP.

| Rol | Puede |
|---|---|
| `admin` | Todo, incluidos usuarios, roles y parámetros |
| `gerencia` | Aprobar/rechazar, aprobar desembolsos (Diego, único firmante BG), ver cartera y reportes |
| `analista` | Revisar expedientes, pedir información, aprobar dentro de su límite, reenviar documentos |
| `operaciones` | Afiliados, cargas de base, estados de cuenta mensuales, conciliación |
| `contabilidad` | Solo lectura de desembolsos, cobros y comisiones; recibe notificaciones (Gisela) |
| `soporte` | Solo lectura del expediente; atender solicitudes de cartas y dudas |

**Externos**

| Rol | Puede |
|---|---|
| `afiliado_admin` (RRHH principal) | Crear/desactivar usuarios de su empresa, cargar base, confirmar datos (Camino B), firmar carta de descuento, ver estado de cuenta y novedades |
| `afiliado_usuario` | Cargar base y ver solicitudes de su empresa |
| `cliente` | Solo sus propias solicitudes, préstamos y documentos |

Reglas:
- Permisos como **acciones** (`solicitud.aprobar`, `desembolso.aprobar`, `parametros.editar`, `base.cargar`…) asignadas a roles en tabla `rol_permisos`, editable por `admin`. Cada acción se valida en servidor y en RLS; el menú solo muestra lo permitido.
- Un usuario puede tener más de un rol; los externos siempre quedan limitados a su `id_afiliado` o a su `nuc`.
- Límites por rol configurables (p. ej. `analista` aprueba hasta $X); con los montos actuales no aplica doble control.
- Acciones sensibles (`desembolso.aprobar`, `parametros.editar`, `usuarios.editar`) piden OTP de nuevo en el momento.

### 4.6 Reglas financieras (heredadas y probadas en la v1 Zoho — la app las replica exactamente)

**a) Cuota quincenal.** Interés mensual flat sobre el monto original, tasa del afiliado, pago quincenal:

```
cuotas        = plazo_meses × 2
interes_total = monto × tasa_afiliado / 100 × plazo_meses          (flat sobre el monto original)
total_pagar   = monto + interes_total                              (capital + interés flat; es el total de LoanDisk)
cuota         = redondear2( total_pagar / cuotas )                 (= monto/cuotas + monto × tasa_afiliado/100/2)
ultima_cuota  = total_pagar − cuota × (cuotas − 1)                 (absorbe la diferencia de centavos)
tasa_nominal  = tasa_efectiva = tasa_afiliado   (mismo número en los documentos)
```
Decisión 02-oct-2026 (Gianclaudio): `total_pagar` es capital + interés flat, **no** `cuota × cuotas`; la cuota se redondea a centavos y el ajuste va en la última cuota. El calendario que devuelve LoanDisk es la fuente de verdad del snapshot; si LoanDisk difiere del total o de las cuotas calculadas, `mp_loandisk_crear` **alerta** al analista y a Diego y no se absorbe en silencio.
Verificado en SO-00078 (préstamo 11909610): $100, tasa 24 %, 3 meses → total 172.00, 5 cuotas de 28.67 + última de 28.65. SO-00079 (11913796): $300, 24 %, 3 meses → total 516.00, 6 cuotas de 86.00.

| Ejemplo $300, tasa 4 % | Cuotas | Cuota | Última cuota | Total |
|---|---|---|---|---|
| 3 meses | 6 | 56.00 | 56.00 | 336.00 |
| 6 meses | 12 | 31.00 | 31.00 | 372.00 |
| 9 meses | 18 | 22.67 | 22.61 | 408.00 |
| 12 meses | 24 | 18.50 | 18.50 | 444.00 |

Solo 3 meses queda habilitado al inicio; 6/9/12 se activan desde `/admin` sin cambios de código. El motor y sus tests cubren los cuatro desde el Brief 06.

**b) Fecha de inicio de descuento** (regla de Gisela; se elimina el +30 días): la **próxima fecha de pago de planilla estrictamente posterior a la fecha de la solicitud**, según el ciclo del colaborador. Si la solicitud cae el mismo día de pago, el primer descuento es el siguiente.

- Ciclo `15-30`: días 15 y último día del mes (30, 31 o 28/29 en febrero). Ciclo `10-25`: días 10 y 25.
- Ejemplos: solicitud 29-sep → `15-30`: 30-sep; `10-25`: 10-oct. Solicitud 28-feb → `15-30`: 15-mar; `10-25`: 10-mar. Solicitud 15-oct con `15-30` → 31-oct.
- Parámetro `dias_minimos_antes_primer_descuento` (default 0; si FIC quiere margen, p. ej. 3 días, se salta a la siguiente quincena).
- Las cuotas siguientes caen en cada fecha de pago del ciclo; la última es el vencimiento. El calendario se genera en la app y debe coincidir con el que arma LoanDisk con el esquema del ciclo.

**c) Afiliados con más de un ciclo de planilla.** Una empresa puede pagar `15-30`, `10-25` o **ambos** (hoy `Frecuencia_de_Planilla` en CRM es multiselección; la app lo modela como lista de ciclos). El ciclo se resuelve **por colaborador**, no por empresa:

1. Si el afiliado tiene un solo ciclo, se asigna automático y no se pregunta.
2. Si tiene dos, **el solicitante elige en el wizard cuál es el ciclo en que le descuentan** (paso 3, antes del cálculo). Si la Base Diaria trae `ciclo_planilla` para su cédula, aparece preseleccionado y puede cambiarlo; la diferencia se marca al analista. En Camino B, RRHH confirma el ciclo con los demás datos laborales.
3. Con el ciclo elegido la app muestra al solicitante la fecha de su primer descuento, la cuota y el total antes de enviar.
4. El ciclo viaja a la solicitud (`ciclo_planilla`), determina la fecha de inicio y selecciona el `loan_payment_scheme_id` de LoanDisk. Si el ciclo no tiene esquema configurado, la solicitud se detiene en `desembolso_pendiente` con alerta (mismo comportamiento que el 05 v2 hoy).

**d) Salario y capacidad.** El salario mensual lo declara el solicitante en el wizard (decisión de Gisela); la app lo contrasta con `salario_neto` de la Base Diaria y marca la diferencia al analista sin bloquear. El % máximo de descuento (por afiliado) se evalúa sobre `descuentos_actuales + cuota × 2` contra el salario mensual.

**e) Snapshot.** Al enviarse la solicitud se congelan monto, plazo, tasa, ciclo, fecha de inicio, calendario de cuotas y total (`evaluaciones.snapshot`); los 4 documentos, LoanDisk y el estado de cuenta se generan desde ese snapshot, nunca recalculando.

**Tests obligatorios (Brief 06):** los cuatro plazos con $100/$150/$200/$300 y tasas 4 %, 16 %, 24 %; inicio de descuento para solicitudes en los días 1, 9, 10, 14, 15, 24, 25, 29 y 30/31 con cada ciclo (el mismo día de pago no cuenta); 28-feb → 15-mar y 10-mar; meses de 28, 29, 30 y 31 días; afiliado con dos ciclos; casos SO-00078 y SO-00079 exactos; última cuota con ajuste de centavos (5 × 28.67 + 28.65 = 172.00; $300 al 4 % a 9 meses: 17 × 22.67 + 22.61 = 408.00).

### 4.7 Back-office (`/admin`) — administrable sin tocar código

Roles y permisos: ver §4.5.

- **Parámetros de producto y por afiliado**: ver §4.4. Todo editable desde `/admin`, con vigencia y auditoría.
- **Bandeja de solicitudes**: filtros por estado/afiliado/analista; vista de expediente (datos, KYC con score, documentos, timeline, resumen IA del expediente); acciones: aprobar / rechazar (motivo) / pedir info / cambiar condiciones. Aprobación por un solo `analista`; doble control configurable por monto en `parametros` (desactivado por defecto, ver §13.7).
- **Documentos y firmas**: ver estado de cada firmante, reenviar recordatorio, cancelar y regenerar sobre.
- **Desembolsos**: cola de aprobados → Diego (único firmante BG) revisa y aprueba → N8N BG H2H → estado (`enviado / procesado / rechazado`) por polling (Flow 07) → confirmación WhatsApp al cliente → `06_Desembolso`.
- **Afiliados**: alta (escribe CRM), tasa, contactos, estado de contrato, última carga de base, empleados activos, cartera.
- **Cartera y cobros**: sincronización LoanDisk, mora, remesas por afiliado, conciliación.
- **Auditoría**: buscador por NUC con la línea de tiempo completa (§6) y exportación.
- **Salud del sistema**: última ejecución de cada workflow N8N, errores, tokens Zoho próximos a vencer, cola de webhooks fallidos con reintento.

---

## 5. Flujo de documentos y firmas (Zoho Sign)

**Requisito:** el solicitante recibe **UN solo correo** con los 4 documentos; los demás documentos van a sus firmantes por separado y en orden.

Implementación:
- Un **solo request de Zoho Sign** (`createUsingTemplate` no permite multi-template → usar `POST /requests` con `documents[]` = 4 PDFs pre-rellenados desde los templates, o un template combinado "Paquete MP" de 4 documentos con un solo firmante `Deudor`). **Validar primero en sandbox cuál de las dos vías conserva los campos de merge**; documentar en el brief.
- Segundo firmante: `RRHH_Afiliado` firma la **Carta de Descuento Directo** (mismo request con `signing_order` después del solicitante, o request separado — validar en sandbox). La firma de FIC (Diego) va **pre-incrustada** en los templates; no hay firmante interno activo ni aprobador en Sign.
- Recordar: `request_name` va dentro de `actionMap`.
- Webhook Sign → N8N `mp-sign-events`: por cada `RequestCompleted` descarga PDF + certificado → WorkDrive `03_Documentos_Firmados` (naming `{NUC}_{tipo}_{fecha}.pdf`) → guarda `WD_*_ID` en CRM y `documentos` en Supabase → avanza estado.
- Documentos no firmados en 72 h: recordatorio automático (WhatsApp + email); a los 7 días: alerta al analista; a los 15 días: expira y se archiva.
- Textos de los documentos: variables desde `parametros` (tasa, FECI, comisión…) para que cambios legales no requieran tocar templates cuando sean solo cifras.

---

## 6. Auditoría, cliente único y cumplimiento

- Tabla `audit_events` **append-only** (sin UPDATE/DELETE; trigger que lo impide): `id, nuc, solicitud_id, actor_type (cliente|afiliado|interno|sistema|n8n), actor_id, accion, entidad, antes (jsonb), despues (jsonb), ip, user_agent, origen (app|crm|n8n|sign|bg), hash_prev, hash` — cadena de hashes para detectar alteración.
- Todo evento relevante también se escribe como **Nota** en CRM en la solicitud (lectura humana).
- **Cliente único:** `clientes` con `nuc` único, `cedula` única (normalizada), `crm_contact_id`, `loandisk_borrower_id`. Alta solo vía función `ensure_cliente(cedula)` que busca en Supabase → CRM → crea. Fusión de duplicados solo por `admin` con motivo.
- **Consentimientos** (`consentimientos`): T&C, tratamiento de datos (Ley 81/2019 Panamá), consulta APC, comunicación por WhatsApp — con versión de texto, timestamp, IP.
- **Retención de PII**: fotos de KYC solo en WorkDrive (no en Supabase); Supabase guarda referencias e IDs. Enmascarar cédula/cuenta en logs y en respuestas de la IA.
- Verificación pública de cartas emitidas: `/verificar/{uuid}` muestra validez sin datos sensibles.

---

## 6-bis. Principio de independencia — capas de abstracción

No se construye KYC in-house (liveness, detección de documentos alterados y responsabilidad ante fraude no compensan para préstamos de $100–$300). Lo que sí se hace es **no acoplarse a ningún proveedor**:

- `lib/kyc/provider.ts` — interfaz `KycProvider` (`startSession`, `getResult`, `getArtifacts`) con implementación `IDAnalyzerProvider`. Cambiar de proveedor, o agregar un tier interno para clientes recurrentes con KYC vigente (< 12 meses), es un cambio local.
- Misma regla para `lib/signing/` (Zoho Sign), `lib/core/` (LoanDisk), `lib/banking/` (BG H2H), `lib/messaging/` (WhatsApp Meta) y `lib/storage/` (WorkDrive).
- Ninguna ruta de la app llama a un proveedor externo directamente; siempre por su adaptador, y los adaptadores no contienen lógica de negocio.

## 7. Modelo de datos Supabase (esquema inicial — proyecto `isthmus-mp`)

Esquemas: `public` (operativo), `audit`, `staging` (cargas), `marts` (vistas para dashboards).

Tablas núcleo (mínimo; Claude Code detalla tipos y RLS en Brief 03):
`clientes`, `afiliados` (espejo CRM: `id_afiliado AF-XXXX`, `crm_id`, `tasa`, `wd_*_id`), `usuarios_afiliado`, `usuarios_internos`, `empleados_master`, `base_cargas`, `base_cargas_filas`, `solicitudes` (estado máquina), `solicitud_eventos` (timeline), `kyc_sesiones`, `evaluaciones` (snapshot de reglas aplicadas y resultado), `documentos`, `sign_requests`, `desembolsos`, `bg_transacciones`, `loan_snapshots`, `pagos`, `cartas_emitidas`, `remesas`, `parametros` (+`parametros_hist`), `plantillas`, `notificaciones`, `webhook_inbox` (idempotencia + reintentos), `audit.audit_events`.

Máquina de estados de `solicitudes` (única fuente; CRM refleja el mismo picklist):
`borrador → kyc_pendiente → kyc_ok | kyc_rechazado → evaluacion → pre_aprobada | rechazada → en_revision → aprobada → docs_enviados → docs_firmados → desembolso_pendiente → desembolsado | desembolso_fallido → activa → pagada | mora | cancelada`.
Transiciones solo vía RPC `transicionar_solicitud(id, nuevo_estado, actor, motivo)` que valida la transición, escribe auditoría y encola el write-back a CRM.

Reglas Supabase: DDL con `apply_migration`; GRANTs explícitos por tabla (aprendido en Cotizador); RLS activada en todo; service role solo en server (route handlers / N8N); clientes solo ven filas con su `nuc`; afiliados solo su `id_afiliado`.

---

## 8. Workflows N8N (nuevos y reutilizados)

| ID lógico | Trigger | Función |
|---|---|---|
| `mp_lookup_cedula` | HTTP desde app | (Solo Opción A) consulta Creator, cachea |
| `mp_kyc_start` / `mp_kyc_callback` | App / IDAnalyzer | Crea sesión DocuPass, recibe resultado, sube archivos a `01_KYC`, guarda `IDAnalyzer_Session_ID` en CRM |
| `mp_solicitud_crear` | App (cola `webhook_outbox`) | Crea/actualiza `Solicitudes_Microprestamo`, contacto, carpetas WorkDrive (o reutiliza Flow "Crear Carpetas Microprestamo"), PDF formulario |
| `mp_sign_enviar` | App (estado `aprobada`) | Construye paquete de 4 docs, request adicional RRHH/Gerencia; guarda Request IDs (reemplaza `mp_enviar_a_zoho_sign1`) |
| `mp_sign_events` | Webhook Sign | Reemplaza `mp_sign_guardar_docs` + `mp-carta-firmada`; sube PDFs/certs, avanza estado |
| `mp_loandisk_crear` | Estado `docs_firmados` | Borrower + Loan (IDs `loan_product_id`, `loan_disbursed_by_id`, `loan_payment_scheme_id` tomados del workflow Monday vigente, guardados en `parametros`) |
| `mp_bg_desembolso` | Aprobación de Diego en `/admin` | **Reutiliza el workflow BG H2H en producción** (adaptar input desde Supabase en vez de Monday; único firmante Diego) |
| `mp_bg_polling` (Flow 07) | Cron 10 min | Estado de transferencias → `bg_transacciones` → notificación |
| `mp_base_diaria_ingest` | Storage upload | Validación + reporte + upsert + copia a WorkDrive + upsert Creator (compat) |
| `mp_afiliado_alta` | Regla CRM `field_update` de `Afiliados.Taza_de_Interes` con `WorkDrive_Folder_ID` vacío (solo vacío → lleno, R42) | Reemplaza el Flow "Crear Carpetas Afiliados": crea carpetas WorkDrive, guarda IDs en CRM, genera el convenio (Writer) y avisa a Diego. Idempotente: si el afiliado ya tiene carpetas, no hace nada y lo registra |
| `mp_loandisk_sync` | Cron 30 min + bajo demanda | Saldos, cuotas, pagos → `loan_snapshots`, `pagos` |
| `mp_notificar` | Cola `notificaciones` | WhatsApp Meta / email / push con plantilla y reintentos |
| `mp_reconcile_crm` | Cron nocturno | Compara Supabase vs CRM; corrige y audita |
| `mp_recordatorios` | Cron diario | Firmas pendientes, cuotas próximas, cargas de base atrasadas |
| `mp_digest_diario` | Cron 7:00 | Resumen Claude para analista/gerencia (solicitudes, mora, alertas) |

Patrón obligatorio: todo webhook entrante se registra en `webhook_inbox` con `idempotency_key` antes de procesar; toda llamada saliente de la app a N8N sale de `webhook_outbox` con reintento exponencial. `get_workflow_details` después de cada cambio de canvas.

---

## 9. Notificaciones y experiencia

Canales: WhatsApp (principal), email (respaldo y documentos), push PWA. Momentos: solicitud recibida, resultado de evaluación, documentos enviados (1 correo con los 4), firma completada, desembolso realizado (con monto y cuenta enmascarada), recordatorio de cuota 3 días antes, pago recibido, carta lista. Tono: formal, breve, con nombre del cliente y NUC. Sin emojis en comunicaciones oficiales.

Accesibilidad y móvil primero: tamaño de toque ≥ 44 px, contraste AA, formularios de un campo por pantalla en móvil, carga de fotos con cámara nativa.

---

## 10. Seguridad y operación

- **Brief 01 (antes de todo):** usuario `deploy` no-root con sudo limitado, Docker rootless o grupo docker, fail2ban, actualizaciones pendientes (33) con ventana de reinicio, backups automáticos de Supabase (Pro) y `docker volumes`.
- Secrets solo en `.env` del contenedor / N8N credentials; nunca en repo. Rotación documentada.
- Rate limiting en `/api/*` público (lookup de cédula, OTP) + captcha invisible.
- Headers de seguridad en Caddy; HSTS; CSP.
- Logs estructurados (pino) con `nuc` y `request_id`; sin PII.
- Health checks: `/api/health` (DB, N8N, Zoho token, LoanDisk) → alerta WhatsApp al admin.
- Pruebas: unitarias para el motor de reglas y cálculo de letra (casos de borde documentados con los números de un préstamo real anonimizado); e2e Playwright del wizard; ambiente `staging` en puerto 3013 con Supabase branch.

---

## 11. Configuración de Claude Code (raíz del repo)

`CLAUDE.md` debe contener: resumen de §2–§3, convenciones (briefs, commits, modo aprobación), comandos (`docker compose up -d --build mp-app`), y la lista de MCPs/skills a usar:
- **MCPs:** Supabase, n8n, Zoho CRM (data + data-operations + insights), Zoho WorkDrive, Zoho Sign, Zoho Creator, Gmail (pruebas de correo). Monday solo para leer el flujo BG existente durante la migración.
- **Skills/plugins:** `supabase:supabase`, `supabase:supabase-postgres-best-practices`, `superpowers:brainstorming` (antes de cada brief nuevo), `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `frontend-design`, `operations:runbook` (para el runbook de desembolsos), `operations:risk-assessment` (Brief 00).
- **Hooks sugeridos:** pre-commit lint+tsc; post-migration `supabase gen types`.

---

## 12. Plan de briefs y calendario (3 semanas)

Ritmo real con agentes + subagentes y decisiones resueltas en el día. Cada brief cierra con pruebas ejecutadas y `git commit`.

**Semana 1 — núcleo en staging**

| # | Brief | Modo |
|---|---|---|
| 00 | Risk assessment, `CLAUDE.md`, repo, sistema de diseño aprobado | manual |
| 01 | Hardening VPS (usuario no-root, fail2ban, backups), DNS `mp.`, staging | manual |
| 02 | Scaffold Next.js 14 PWA `mp-app` (puerto 3003), marca MP (`public/brand/mp-logo.png`, tokens `--mp-*`, `mpPreset`; FIC como respaldo, §19.9), Caddy, Docker | auto |
| 03 | Supabase `isthmus-mp`: esquema **multi-producto y versionado** (§19.11) con historial de tasas por afiliado (§19.10), RLS, RPC `transicionar_solicitud`, cadena de auditoría | manual |
| 04 | Auth: OTP WhatsApp + magic link, roles internos, `usuarios_afiliado` | manual |
| 05 | Adaptadores (`kyc_provider`, signing, core, banking, messaging) + espejo CRM→Supabase de `Afiliados` | auto |
| 06 | Motor de reglas: cuota quincenal 3/6/9/12, inicio de descuento por ciclo (uno o dos ciclos), % descuento — **tests primero** (§4.6) | manual |
| 07 | Wizard cliente pasos 1–3, incluye Camino B | manual |
| 08 | Wizard 4–6 + `mp_solicitud_crear` + carpetas WorkDrive (N8N, sin Flow) + PDF formulario | manual |

**Semana 2 — punta a punta y piloto**

| # | Brief | Modo |
|---|---|---|
| 09 | Back-office: bandeja, expediente, aprobación, parámetros por afiliado (tasa y comisión de **solo lectura desde CRM** durante la convivencia, con historial §19.10; %, SLA) y del producto existente (sin alta de productos, §19.11) | auto |
| 10 | Paquete único de 4 documentos en Sign + firma RRHH + `mp_sign_events` | manual |
| 11 | LoanDisk: crear borrower y préstamo (IDs tomados del flujo Monday vigente) | manual |
| 12 | Desembolso BG H2H desde la app (firmante único Diego) + polling + notificación a Gisela | manual |
| 13 | Notificaciones WhatsApp/email/push con plantillas administrables | auto |
| 14 | Prueba end-to-end en staging y **piloto en producción con el afiliado del Camino B** | manual |

**Semana 3 — afiliados, cobro y cierre**

| # | Brief | Modo |
|---|---|---|
| 15 | Portal afiliado: plantilla descargable + carga de Base Diaria con validación (ANEXO A + `ciclo_planilla`) + copia a WorkDrive | manual |
| 16 | Portal cliente post-desembolso: estado de cuenta, historial, recibos | auto |
| 17 | Cartas de saldo / paz y salvo con QR de verificación | manual |
| 18 | Estado de cuenta mensual al afiliado (formato ANEXO), pago consolidado, conciliación y novedades laborales | manual |
| 19 | Reconciliación CRM, digest diario, salud del sistema, runbooks, **apagar Creator y Flow**, edición de tasa y comisión en `/admin` con validación de rango y write-back a CRM (§19.10) | manual |

**Post-lanzamiento (no bloquea el piloto del Brief 14 ni el cierre del Brief 19)**

| # | Brief | Modo |
|---|---|---|
| 20 | Catálogo de productos en `/admin` (§19.11): alta y versionado de productos; montos, plazos, frecuencia y rango de tasa; producto y ciclos LoanDisk; documentos requeridos; plantillas de firma; reglas de elegibilidad; niveles de aprobación por monto; pasos activables del catálogo fijo. Requiere los controles para montos altos definidos con Diego (R43) | manual |

Fuera del loop de agentes (pedir el día 1): aprobación de la plantilla WhatsApp por Meta (1–3 días) y tiempos de respuesta de los sandbox de BG y Sign.

## 13. Decisiones cerradas (1 sep 2026) — vinculantes para todos los briefs

1. **Sign:** un solo request / un solo correo al solicitante con los 4 PDFs (Contrato, Pagaré, Carta, APC). Validar en sandbox que el merge de campos se conserva al combinar.
2. **Firmantes:** solicitante y RRHH del afiliado. Diego Méndez ya está **pre-firmado** en los documentos (firma de FIC incrustada en el template; no es un firmante activo en Sign). No hay paso de "aprobación gerencia" en Sign ni copia a contabilidad por Sign; contabilidad recibe notificación por la app.
3. **Desembolso BG:** **Diego Méndez es el único firmante/aprobador** en la cuenta BG. Alberto Mizracchi ya no aprueba. **Gisela recibe notificación de cada desembolso** (confirmado por ella). Zsaydee Salas: verificar en Brief 12 si sigue en la lista.
4. **IDs LoanDisk:** tomarlos del workflow BG/LoanDisk que hoy corre desde Monday (ya corregidos ahí). Brief 11 los lee con el MCP de n8n, los documenta en `parametros` y no los hardcodea. Monday se suspenderá; Zoho queda.
5. **Base Master:** **Opción B** (visto bueno de Diego para retirar Flow y Creator) — carga por portal del afiliado, Supabase como fuente, copia a WorkDrive `Base Diaria` como histórico. El trigger de carpetas pasa de Zoho Flow a N8N. El formulario Creator se apaga al terminar el piloto (Brief 19).
11. **Camino B:** habilitado como `Modo_Validacion` por afiliado (§4.3-bis). El afiliado piloto se define al momento de la prueba.
12. **Tasa:** la del ANEXO (18 %) es plantilla; **la tasa real se coloca por afiliado** (confirmado). El % máximo de descuento, SLA y días de transferencia también son por afiliado.
13. **Identidad visual:** §15. Las pantallas clave se diseñan y aprueban en Claude Design antes del Brief 02.
6. **OTP cliente:** **WhatsApp Meta Cloud API** (plantilla de autenticación aprobada, número dedicado MP) + magic link por correo como respaldo. Sin SMS. Modelo de plantilla en §14.
7. **Montos y doble control:** montos iniciales $100, $150, $200 y $300, **parametrizables** (§4.4). Con esos montos no aplica doble control; el umbral queda desactivado y configurable por rol (§4.5).
8. **Cobro/remesas:** FIC envía al afiliado a fin de mes un **estado de cuenta detallado** (préstamo por préstamo con su cuota y total) y el afiliado hace **un solo pago consolidado**. Brief 17 automatiza exactamente eso: generar el estado de cuenta desde LoanDisk, publicarlo en `/afiliado` y enviarlo por correo, recibir el comprobante, aplicar los pagos en LoanDisk y alertar diferencias. **Confirmado por Gisela:** los estados de cuenta se emiten desde **LoanDisk**, tanto el individual del cliente (Cronograma de Pagos del Préstamo) como el del RRHH del afiliado (formato ANEXO). La app los genera con los mismos campos.
9. **Dominio:** `mp.isthmuscap.com`. `microprestamos.isthmuscap.com` se redirige a `mp.` cuando entre en producción.
10. **Consentimientos:** reutilizar **tal cual** los T&C y la autorización APC actuales como versión 1 en `plantillas`.

---

## 14. WhatsApp Meta — plantilla aprobada (23 sep 2026)

La plantilla `fic_mp_codigo_acceso` (categoría Autenticación, español, botón *Copiar código*, caducidad 10 min) está **activa y aprobada por Meta**. Datos entregados por Ana Gabriela Fracasso (Marketing Operativo):

| Dato | Valor |
|---|---|
| WhatsApp Business Account ID | `4466216373701343` |
| Phone Number ID | `1184886231372996` |
| Número | +507 6334-9586 |
| App ID | `1360854289567229` |
| Token de acceso | **Solo en `.env` del servidor y en la credencial de N8N `Meta WhatsApp MP`. Nunca en el repo, briefs ni documentos.** |

Pendientes del Brief 04: verificar el token con el *Access Token Debugger* de Meta (debe ser de usuario del sistema y sin caducidad); como viajó por correo, planificar su rotación una vez la app esté en producción. Las demás notificaciones usan plantillas **UTILITY** (una por evento) que se redactan en el Brief 13 y se envían a Meta con el mismo proceso.

---

## 15. Identidad visual y proceso de diseño

**Marca del producto (decisión 02-oct-2026, §19.9): "MP Micropréstamos — Avanzamos Contigo"**, logo `public/brand/mp-logo.png` (PNG con fondo transparente). La app, la PWA, los correos y los PDF llevan la marca MP; **FIC aparece como respaldo** ("Un producto de Financiera Isthmus Capital", con su logo `public/brand/logo.png`) en inicio de sesión, pie de página y documentos. Los tokens anteriores `--fic-*` (`#193A76` / `#66A5E6`) quedan retirados; FIC no tiene tokens propios.

**Tokens de marca** (medidos del logo real; valores completos y escalas en `styles/tokens.css`, auditoría en `docs/design/README.md`):

```css
:root {
  --mp-azul:         #02265E;  /* primario: cabeceras, botones, bloque de cifra, enlaces (14.6:1 sobre blanco) */
  --mp-azul-900:     #011A42;  /* hover/pressed */
  --mp-azul-50:      #EAF0FA;  /* tinte del primario: fila seleccionada */
  --mp-acento:       #1B70DE;  /* acento: estado activo, foco, gráficos (4.75:1 sobre blanco; como texto solo sobre blanco) */
  --mp-acento-700:   #1457B3;  /* acento como texto sobre fondos claros (6.9:1) */
  --mp-acento-100:   #DCEAFC;  /* tinte del acento */
  --mp-acento-claro: #8DC0F7;  /* acento sobre superficies azules (7.6:1 sobre azul) */
  --mp-gris-100:     #F4F6FA;  /* fondo de página y tarjetas suaves */
  --mp-gris-600:     #5B6472;  /* texto secundario */
  --mp-texto:        #16213A;  /* texto principal */
  --mp-exito:        #1F7A4D;
  --mp-alerta:       #B45309;
  --mp-error:        #B42318;
}
```

Tipografía: una sans geométrica sobria, sin fuentes decorativas. Sin gradientes, sin sombras marcadas, sin ilustraciones genéricas. Logo MP en cabecera de la app, en los PDFs y en el correo; respaldo FIC en pie y login. Esquinas suaves, mucho espacio en blanco, un solo acento de color por pantalla (el acento nunca sustituye al primario en botones ni enlaces). Íconos de la PWA provisionales recortados del PNG (`public/icons/`) hasta recibir el SVG oficial.

**Estados del préstamo** (mismos colores que LoanDisk, para que FIC los reconozca): Current, Due Today, Missed Repayment, Arrears, Past Maturity.

**Proceso:**
1. **Antes del Brief 02** — sesión en Claude Design (1–2 h) sobre 5 pantallas clave: wizard del cliente (paso de monto), línea de tiempo de la solicitud, estado de cuenta, carga de Base Diaria con reporte de errores, bandeja de admin. Se itera con Diego en el canvas. **Decisión 02-oct-2026 (§19): la sesión se hace con Gianclaudio, no con Diego; las 5 pantallas se preparan en HTML con los tokens de marca al cierre del Brief 01 (eran `--fic-*` esa mañana; renombrados a `--mp-*` el mismo día, §19.9) y se revisan en celular.**
2. El resultado se congela como `docs/design/` + `styles/tokens.css` + configuración de Tailwind. **02-oct-2026 (tarde):** las 5 pantallas, la página de tokens y la página de espera se regeneraron con la marca MP; Artifact privado actualizado para la revisión en celular.
3. Cada brief de UI referencia la pantalla aprobada y usa el skill `frontend-design`.
4. Cada brief de UI cierra con capturas de Playwright (móvil 390 px y escritorio 1440 px) comparadas contra el diseño.

---

## 16. Adiciones del 28 sep 2026 (vinculantes)

1. **Parametrización total** (§4.4): plazos (3/6/9 meses, default 3 — Diego prefiere 3 en lugar de 9), montos, frecuencia, tasa por afiliado, % de descuento, comisiones y fees se administran desde `/admin`.
2. **Tasa por afiliado → LoanDisk:** fuente única CRM `Taza_de_Interes`, que Diego completa después del formulario y que además dispara la generación del convenio. Brief 00 documenta cómo viaja hoy a LoanDisk; la app replica ese camino. **Precisión 03-oct-2026 (§19.14):** en CRM la única automatización de `Afiliados` dispara en `create`, no sobre la tasa; el disparador objetivo en N8N reacciona solo cuando la tasa pasa de vacío a lleno (R42).
3. **Usuarios internos/externos y permisos** (§4.5), administrables por `admin`.
4. **Convenio de afiliación firmado en físico** (Writer → impresión → firma → escaneo a WorkDrive). Sign solo se usa para los 4 documentos del solicitante y la carta de descuento de RRHH.
5. **BG H2H está en producción (LIVE):** genera transferencias reales. Ninguna prueba, en ningún brief, puede llegar a ejecutar un desembolso. El adaptador `lib/banking` tiene modo `dry_run` activado por defecto en staging y el Brief 12 se prueba contra sandbox o con `dry_run`.
6. **Convivencia:** el primer afiliado real entra por el flujo actual (Zoho Forms "Formulario de Afiliación Empresarial" + CRM + N8N, sin Monday). La app lo absorbe después; los préstamos de Seguridad Unida siguen en el sistema Monday hasta su migración.
7. **WhatsApp:** plantilla aprobada; datos en §14.

---

## 17. Adiciones del 29 sep 2026 (vinculantes)

1. **Inicio de descuento** = próxima fecha de planilla estrictamente posterior a la solicitud (confirmado con el caso 28-feb → 15-mar / 10-mar), según el ciclo del colaborador (§4.6-b). Se elimina la lógica de +30 días.
2. **Afiliados con uno o dos ciclos** (`15-30`, `10-25`): el ciclo se define por colaborador (Base Diaria o elección + confirmación de RRHH) y selecciona el esquema de LoanDisk (§4.6-c). Pendiente: Gisela crea en LoanDisk el esquema quincenal `10-25`; `15-30` = 4418.
3. **Cuotas** siempre quincenales; plazo 3/6/9/12 meses con la fórmula de §4.6-a. Se inicia solo con 3 meses.
4. **Plantilla de Base Diaria descargable** desde el portal del afiliado, generada desde el contrato de datos (§4.2).
5. El **salario mensual** lo declara el solicitante; la base sirve de contraste, no de fuente (Gisela).

---

## 18. Aprendizajes de la v1 en producción (30 sep – 1 oct 2026) — vinculantes

La v1 (Creator → CRM → Sign → N8N → LoanDisk → BG) quedó funcionando de punta a punta con SO-00078. La app **replica estas soluciones, no las redescubre**:

**LoanDisk**
- Producto: **383523 "Micropago Flat 1025"** — Flat Rate (interés sobre el monto original, cuota constante), validado por Gisela. Rango de interés del producto min 18 / max 30; la tasa enviada es la del afiliado y **la app la valida contra ese rango antes de guardarla** (§19.10, R41); el rango se guarda como parámetro de producto y, si FIC necesita una tasa fuera de él, Gisela ajusta primero el producto en LoanDisk. Los productos 369108/369109 y 383112 **no** se usan.
- Ciclos de pago a fechas fijas: **10-25 = 4646**, **15-30 = 4418**. Se elige por el ciclo del colaborador (§4.6-c). Pendiente: habilitar 15-30 en el producto 383523.
- **Nunca usar el ciclo "Bimonthly" (ID 12)**: vía API genera cuotas cada 2 meses, no quincenales.
- Los ciclos se crean en la UI de LoanDisk, no por API. Branch por afiliado lo asigna Gisela (AF-0033 → 92588).
- Préstamo de referencia correcto: **11909610** (SO-00078, $100, 24 %, 6 cuotas de 28.67 el 10 y 25 de oct–dic, total 172.00).
- Préstamos de prueba creados a mano en LoanDisk **no** usan números SO ni numeración en secuencia (bloquearon un préstamo real).

**Zoho Sign**
- Sobre único sin plantilla combinada: API `templates/mergeview` + `templates/mergesend` unen las 4 plantillas en un solo envío; el mismo `request_id` se guarda en los 4 campos `Sign_Request_ID_*`.
- El correo de firma sale a nombre de **Isthmus Capital** (plantilla de email de Sign modificada), con el nombre del solicitante.
- Hoy lo hace la función Deluge `mp_enviar_a_zoho_sign1` (conexión `zoho_sign`); el 04 (`HeXyYSjeUXu5qTBi`) guarda los 4 PDF por separado con nombre y certificado (la Carta va también a RRHH).

**Banco General**
- **06 prod** (`GTFFlEfXa0LOTtnF`): genera la transferencia pendiente en Banca en Línea que Diego aprueba o rechaza. No se modifica.
- **06 QA** (`EQOqUBQp1N60zFlG`, ambiente `bg-h2h-qa2`, cuenta de certificación 0301011367700): para todas las pruebas. Probado OK (codigoPago 12317).
- El 05 v2 (`iPM3haUtdcof745M`) decide con `bg_ambiente = 'qa' | 'prod'`. **La app usa el mismo parámetro**: staging y pruebas siempre `qa`; `prod` solo con aprobación explícita.

**Correos**
- Todo correo del flujo MP sale de **gestionprestamos@isthmuscap.com** (N8N: credencial Gmail "Gmail account 2", `l3e9P4UxBqKXKir4`), nunca de facturasfic@.

**KYC**
- El callback de IDAnalyzer puede llegar **antes** que la solicitud: el proceso debe esperarla/asociarla después, no fallar. En la app esto se resuelve porque la solicitud existe desde el paso 1 del wizard, pero `mp_kyc_callback` debe tolerar el orden inverso igual. **Precisión 02-oct-2026 (§19):** en la app nunca existe una sesión KYC sin solicitud; el callback trae el id de la solicitud y la tolerancia al orden inverso queda como defensa (cola de huérfanos + alerta).

---

## 19. Decisiones del 02-oct-2026 (vinculantes)

1. **Solicitud desde el paso 1.** La solicitud se crea en estado `borrador` en el primer paso del wizard (cédula) y todo lo que sigue cuelga de ella: la sesión KYC se asocia a esa solicitud (**nunca existe una sesión KYC sin solicitud**), igual que los datos, la aceptación de T&C y el envío. `mp_kyc_callback` recibe el identificador de la solicitud en el callback; la tolerancia al orden inverso (§18) queda solo como defensa (cola de KYC huérfanos visible en `/admin` + alerta).
2. **Wizard reanudable con OTP.** El guardado es automático por paso; el cliente retoma el wizard autenticándose con OTP (canal de §13.6) y la app lo lleva al último paso incompleto. Sustituye el "reanudable por link mágico" de §4.1.
3. **IDAnalyzer redirige al formulario.** Al aprobar la verificación, IDAnalyzer DocuPass redirige al cliente de vuelta al wizard. El WhatsApp con el enlace al formulario es un **respaldo**, no el camino principal; por eso el residual del 03 KYC v1 (WhatsApp al final de la rama, hasta 30 min tarde) baja a prioridad **Baja** (`docs/RIESGOS.md` R34).
4. **Sesión de diseño con Gianclaudio.** Cambia el interlocutor de §13.13 y §15.1: las 5 pantallas clave se preparan en **HTML con los tokens de marca** (`styles/tokens.css`; eran `--fic-*` esa mañana y pasaron a `--mp-*` el mismo día, §19.9) al cierre del Brief 01 y se revisan con Gianclaudio en celular; Diego no participa en esa sesión. Lo aprobado se congela en `docs/design/` antes del Brief 02.
5. **Calidad de UI** (reglas en `CLAUDE.md`). Cada brief con pantallas cierra con: captura móvil 390 px y escritorio 1440 px por pantalla; `design:accessibility-review` antes de cerrar; textos revisados con `design:ux-copy` (ningún error técnico visible al usuario); flujo reanudable; prueba en celular real antes de aprobar el brief.
6. **Remoto y ritmo de commits.** Repo privado `https://github.com/isthmus-capital/mp-app.git` (`origin`; `main` sincronizado el 02-oct-2026). Cada `git commit` va seguido de `git push` (R11 cerrado).
7. **Calendario.** Supabase Pro se activa el 03-oct-2026. Si el Brief 01 necesita el proyecto `isthmus-mp` antes, ese paso queda pendiente y el brief sigue con el resto. Brief 01 aprobado para iniciar el 02-oct-2026.
8. **Supabase Pro activado y proyecto creado (02-oct-2026, un día antes de lo previsto en el punto 7).** Organización `Isthmus Capital` en plan Pro; proyecto **`isthmus-mp`**, ref **`waqvypbjicddmknwerip`**, región **us-west-2 (Oregon, junto al VPS)**, compute Micro, Postgres 17, estado `ACTIVE_HEALTHY` (verificado por MCP), sin ramas. Configuración del panel: RLS automática en tablas nuevas **activada** y "expose new tables" **desactivado** (toda tabla necesita `GRANT` explícito, regla §7). Las claves **no viajan por chat**: Gianclaudio las copia del panel a `/etc/mp-app/staging.env` y `/etc/mp-app/production.env` (640 `root:deploy`) con estos nombres, iguales en los dos archivos:

   ```bash
   NEXT_PUBLIC_SUPABASE_URL=https://waqvypbjicddmknwerip.supabase.co
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=   # Project Settings → API Keys → Publishable key (sb_publishable_…); pública por diseño
   SUPABASE_URL=https://waqvypbjicddmknwerip.supabase.co
   SUPABASE_SECRET_KEY=                    # API Keys → Secret keys → Create new key: una por ambiente (mp_app_staging, mp_app_production; Supabase no acepta guiones), sb_secret_…; solo servidor
   SUPABASE_PROJECT_REF=waqvypbjicddmknwerip
   ```

   Se usan las claves nuevas (publishable/secret), no las JWT `anon`/`service_role` heredadas (Supabase las retira a fin de 2026); la app nunca necesita la contraseña de Postgres ni el JWT secret (todo pasa por `supabase-js` y el MCP). **Hasta que el Brief 03 cree la rama persistente `staging`, los dos archivos apuntan al mismo proyecto**; entonces `staging.env` pasa a la URL y claves de la rama. Pendiente (Checkpoint F del Brief 01): verificar en el panel → *Database → Backups* que el primer backup diario del plan Pro aparece (24 h después de crear el proyecto).

   **Claves copiadas (02-oct-2026, 19:17–19:18 UTC)** por Gianclaudio a los dos archivos; Claude verificó permisos, nombres y formato sin ver los valores (INVENTARIO §10). La secret key `default` que Supabase crea con el proyecto no la usa ningún `.env` y se revoca cuando la app esté en producción (INVENTARIO §12, ítem 28).
9. **Marca del producto: MP Micropréstamos.** La app usa la marca "MP Micropréstamos — Avanzamos Contigo" (`public/brand/mp-logo.png`, PNG con fondo transparente); FIC aparece como respaldo ("Un producto de Financiera Isthmus Capital") en inicio de sesión, pie de página y documentos. Colores medidos del logo: primario azul marino `#02265E` (14.6:1 sobre blanco) y acento azul medio `#1B70DE` (4.75:1), con escalas derivadas que cumplen AA (§15, `styles/tokens.css`); tokens y preset de Tailwind renombrados de `fic` a `mp` antes de que exista código que los use. Íconos PWA, maskable y favicon provisionales recortados del PNG hasta recibir el SVG. Las 5 pantallas, capturas 390/1440 y el Artifact se regeneraron con la nueva marca; sigue pendiente la revisión en celular.
10. **Tasas por afiliado con historial (Diego, 02-oct-2026; documentado el 03-oct y cerrado el mismo día).** La tasa de interés y la de comisión de un afiliado pueden cambiar (p. ej. 24 % → 36 %). Cada afiliado lleva un **historial de tasas append-only** con valor, vigencia desde, usuario y motivo (tabla propia del Brief 03, distinta de `parametros_hist` y del historial de cargas de Base Diaria `base_cargas`, que se mantiene). Solo el rol `admin` puede cambiarla, con OTP en el momento y auditoría (§4.5). Antes de guardar, la app **valida la tasa contra el rango del producto LoanDisk** (hoy 383523: min 18 / max 30, §18), leído de los parámetros del producto, nunca fijo en código (R41). Un cambio de tasa nunca afecta préstamos existentes.
    - **Dirección de edición (cerrado por Diego).** Durante la convivencia con la v1, la tasa y la comisión se editan **solo en Zoho CRM** (`Afiliados.Taza_de_Interes`, `Tasa_de_Comisi_n`) y la app las lee por el espejo CRM → Supabase (§4.4 se mantiene). Cada valor que llega por el espejo abre una fila del historial (usuario = quien editó en CRM, motivo "edición en CRM") y, si queda fuera del rango del producto, alerta a Diego y Gianclaudio: la validación preventiva no alcanza a las ediciones hechas en CRM. Al apagar la v1 (Brief 19), se editan en `/admin` con historial y validación, y la app alimenta a Zoho por N8N **escribiendo en un campo que no dispare el contrato del afiliado**. Con el disparador del alta propuesto en R42 (solo cuando `Taza_de_Interes` pasa de vacío a lleno y el afiliado no tiene carpetas), escribir `Taza_de_Interes` en un afiliado activo no dispara nada; si se quiere aislar del todo, campo nuevo dedicado, a decidir en el Brief 19.
    - **Congelamiento (cerrado por Diego).** La tasa se congela **al enviar la solicitud** (`evaluaciones.snapshot`, §4.4 y §4.6-e): es la que va en el pagaré. Si la tasa del afiliado cambia mientras la solicitud está en revisión, **se respeta la tasa aceptada por el cliente**; el aprobador ve un **aviso informativo** con la tasa del snapshot y la vigente, sin bloqueo. Queda eliminado el bloqueo de aprobación con alerta que se había anotado para el Brief 06.
    - **AF-0031 (cerrado por Diego).** "Acme Corporation Inc." (`AF -0031`, creado el 18-may-2026) es un afiliado de prueba de los primeros, no real; su tasa 4 % se puede corregir. R41 ajustado: hoy no hay ningún afiliado real fuera del rango y el control de validación de rango se mantiene.
11. **Productos configurables y versionados (Diego, 02-oct-2026; documentado el 03-oct).** La app debe poder crear productos nuevos desde `/admin` (p. ej. préstamos de hasta $10,000) sin tocar código. Cada producto define: montos (lista o rango), plazos, frecuencia, rango de tasa, producto y ciclos de LoanDisk, documentos requeridos (tipo, obligatorio, quién lo sube, validación), plantillas de firma, reglas de elegibilidad (p. ej. 20 % máximo de descuento) y niveles de aprobación por monto. Los productos son **versionados**: la solicitud congela la versión del producto junto con los parámetros (§4.4, §4.6-e). El flujo es un **catálogo fijo de pasos activables por producto** (KYC, validación Base Diaria, APC, comité, firma, desembolso), **no** un diseñador de flujos libre. El esquema de Supabase del **Brief 03 nace multi-producto**, con el producto MP actual como semilla (versión 1); **el lanzamiento va con un solo producto**. Los Briefs 06 (reglas), 09 (parámetros), 10 (firma) y 11 (LoanDisk) leen la configuración del producto en lugar de asumir el único existente, para que un producto nuevo no exija código. La **pantalla de administración de productos** (alta, versiones, documentos, plantillas, niveles de aprobación, pasos) queda en el **Brief 20, después del 19**, sin retrasar el lanzamiento; en el Brief 09 solo se editan los parámetros del producto existente. Los productos de monto alto pueden requerir controles adicionales (APC obligatorio, aprobación de Diego, límites de transferencia BG): **pendiente de definir con Diego** (R43) antes del Brief 20.
12. **Riesgos nuevos en `docs/RIESGOS.md`:** R41 tasa fuera del rango del producto LoanDisk; R42 en la v1 editar `Taza_de_Interes` en CRM puede redisparar el contrato del afiliado; R43 controles adicionales para productos de monto alto (pendiente con Diego). **03-oct (tarde):** R41 y R42 actualizados con la lectura de CRM (§19.14): sin caso real fuera de rango; en la v1 editar la tasa en CRM no dispara nada; propuesta de disparador vacío → lleno y plan de prueba en AF-0033.
13. **Marca MP en los briefs (03-oct-2026).** El Brief 02 (título, objetivo, PWA y criterio de aceptación) y la fila 02 de §12 dicen marca MP (logo `public/brand/mp-logo.png`, tokens `--mp-*`, `mpPreset`) con FIC como respaldo según §19.9; §1 y §4.1 corregidos igual. Las menciones a "tokens FIC" en el historial de versiones, §15.1 y §19.4 se conservan como registro con la nota del renombre; los planes de ejecución de los Briefs 00 y 01 llevan una nota al inicio y no se reescriben.
14. **Lectura de CRM del 03-oct-2026 (solo lectura, MCP de Zoho CRM; nada modificado).** Módulo `Afiliados`: **una sola** regla de workflow, `Afiliados_ZohoFlow_Crear Carpetas Afiliados` (`6982798000004398001`), disparador `create`, sin criterios, acción única webhook a Zoho Flow (`6982798000004397001`; creada por Zoho Flow el 07-may-2026, no editable ni eliminable desde CRM), última ejecución 29-sep-2026 12:45:02, que coincide con la creación de AF-0033. **Ninguna** regla, field update, tarea ni función sobre `Taza_de_Interes` ni `Tasa_de_Comisi_n`; el módulo admite el disparador `field_update` con acciones webhook, función y flow. Afiliados existentes, los dos de prueba: `AF -0031` "Acme Corporation Inc." (tasa 4, comisión vacía, creado 18-may-2026) y `AF-0033` "Prueba Inc." (tasa 24, comisión 4, creado 29-sep-2026); ambos con `Estado` vacío, `Estado_del_Contrato = Enviado a firma` y `Fecha_Env_o_Contrato` fijada al crearse, señal de que el paso del contrato va ligado a la creación y no a la tasa. **No visible por MCP, pendiente de revisar a mano:** el interior del Flow (si además genera el convenio en Writer o fija `Estado_del_Contrato`) y las funciones Deluge ligadas a botones o programadas; no existe MCP de Zoho Flow. Propuesta de cambio mínimo y plan de prueba en AF-0033 en `docs/RIESGOS.md` (R42).
