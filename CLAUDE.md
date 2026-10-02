# CLAUDE.md — mp-app (Micropréstamos Isthmus Capital)
<!-- Paquete: v5 — 01-oct-2026 -->

## Qué es esto
Plataforma de micropréstamos por descuento directo para **Financiera Isthmus Capital (FIC), Panamá**.
Tres portales en una sola app Next.js 14: `/cliente` (colaborador, PWA), `/afiliado` (RRHH de la empresa), `/admin` (FIC).
Reemplaza el proceso actual de Zoho Creator + Zoho Flow + Monday, que corre en paralelo hasta el Brief 19.

**Lee `docs/00_PROMPT_MAESTRO.md` completo antes de cualquier brief.** Las decisiones de su §13 son vinculantes.

## Reglas de trabajo
- Un brief a la vez, desde `docs/briefs/NN_*.md`. No empieces el siguiente sin `git commit` + `git push` y pruebas ejecutadas del anterior.
- **Modo aprobación manual** obligatorio en: fórmulas financieras, transiciones de estado, firmas, desembolsos BG, migraciones de Supabase, cualquier llamada a producción.
- Nunca asumas nombres de campos: verifica con los MCP (Zoho CRM, Supabase, n8n) antes de escribir código. El nombre visible en la UI de Zoho **no** es el API name.
- Si un dato de negocio no está en el Prompt Maestro, pregunta. No inventes tasas, plazos ni IDs.
- Tests antes que implementación en el motor de reglas, cálculo de letra y transiciones de estado.
- Verifica antes de decir "listo": corre el comando, lee la salida, muestra la evidencia.
- **Cada `git commit` va seguido de `git push`** a `origin` (repo privado `https://github.com/isthmus-capital/mp-app.git`). Nunca dejes commits sin empujar al cerrar una sesión.

## Arquitectura (resumen)
- **Supabase** (`isthmus-mp`): estado operativo, auth, auditoría. La app nunca llama a Zoho en el request path del cliente.
- **Zoho CRM**: expediente oficial. Si difiere de Supabase, **gana CRM**; `mp_reconcile_crm` corrige de noche.
- **N8N** (`automation.isthmuscap.com`): único orquestador. Zoho Flow queda retirado.
- **WorkDrive** archivos · **Sign** firma · **LoanDisk** core · **BG H2H** desembolso · **IDAnalyzer** KYC · **Meta WhatsApp** mensajería.
- Todo proveedor externo va detrás de un adaptador en `lib/` (`kyc/`, `signing/`, `core/`, `banking/`, `messaging/`, `storage/`). Ninguna ruta llama a un proveedor directamente.
- SQL hace la aritmética; Claude interpreta y resume; N8N mueve datos; Next.js muestra y captura. Cero lógica financiera en el frontend.

## Trazabilidad
El **NUC** (Número Único de Cliente) es la llave de todo. Nunca crear cliente sin NUC ni dos NUC para la misma cédula. Alta solo por `ensure_cliente(cedula)`.

## Estructura
```
mp-app/
  app/(cliente|afiliado|admin)/...
  app/api/...
  lib/{kyc,signing,core,banking,messaging,storage,rules}/
  supabase/migrations/
  docs/00_PROMPT_MAESTRO.md
  docs/briefs/NN_*.md
  docs/design/
  styles/tokens.css
  tests/
```

## Comandos
```bash
docker compose up -d --build mp-app      # build y deploy local/VPS (puerto 3003)
docker compose up -d --build mp-app-staging  # staging (puerto 3013, /etc/mp-app/staging.env)
npm run test                              # unitarios (reglas, letra, transiciones)
npm run test:e2e                          # Playwright (wizard móvil + escritorio)
supabase gen types typescript --project-id <id> > lib/db/types.ts
```

## MCPs y skills
- **MCPs:** Supabase, n8n, Zoho CRM (data / data-operations / insights), Zoho WorkDrive, Zoho Sign, Gmail. Monday solo lectura durante la migración del flujo BG.
- **Skills:** `supabase:supabase`, `supabase:supabase-postgres-best-practices`, `superpowers:brainstorming` (antes de cada brief nuevo), `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `frontend-design`, `design:accessibility-review`, `design:ux-copy`, `operations:runbook`.

## Prohibido (sin excepción)
- **Banco General**: `lib/banking` usa `bg_ambiente`. Staging y toda prueba = `qa` (06 QA `EQOqUBQp1N60zFlG`, cuenta de certificación). `prod` (06 `GTFFlEfXa0LOTtnF`) solo con aprobación explícita de Gianclaudio y Diego. Nunca modificar el 06 prod.
- Nunca escribir tokens, llaves ni contraseñas en el repo, briefs, logs o documentos. Solo `/etc/mp-app/*.env` del servidor (640 root:deploy) y credenciales de N8N.
- Nunca modificar workflows N8N ni registros de Zoho en producción sin mostrar antes el cambio y recibir aprobación.
- **N8N se lee solo por el MCP** (herramientas de lectura: `get_workflow_details`, `list_credentials`, `search_workflows`, `search_workflow_executions`, `get_workflow_execution`). **Prohibido acceder a la base de datos, al contenedor o a los archivos de n8n** en el VPS, por cualquier vía. Nunca `execute_workflow`, `test_workflow`, `prepare_workflow_pin_data` ni publicar/archivar sin aprobación explícita; el 06 prod no se ejecuta ni se modifica jamás.
- Nada financiero fijo en el código: montos, plazos, tasas, fees y límites se leen de los parámetros (§4.4 del Prompt Maestro).

## Gotchas heredados
- LoanDisk: producto 383523, ciclos 4646 (10-25) y 4418 (15-30). Nunca el ciclo Bimonthly (12). Ver §18.
- Correos MP solo desde gestionprestamos@ (credencial N8N `l3e9P4UxBqKXKir4`).
- Préstamos de prueba en LoanDisk: nunca con números SO ni en secuencia.
- Credenciales Zoho en N8N: `V8ToVmg60xSjZasl` para workflows sin WorkDrive; `lRBD9utZoqJjYHEW` cuando hay nodos WorkDrive (Token Expired Status Code = 500).
- Zoho Flow/WorkDrive solo alcanza el Team Folder **General**.
- Nunca `neverError: true` en nodos que llaman APIs externas.
- Después de tocar un workflow: `update_workflow` + `publish_workflow` y verificar `activeVersionId` con `get_workflow_details`.
- Supabase: GRANTs explícitos por tabla, RLS activa en todo, service role solo en servidor.
- Todo webhook entrante se registra en `webhook_inbox` con `idempotency_key` antes de procesar.

## Calidad de UI (obligatorio en cada brief con pantallas)
- **Capturas por pantalla**: móvil 390 px y escritorio 1440 px (Playwright), guardadas en `docs/design/capturas/` y comparadas contra la pantalla aprobada.
- **`design:accessibility-review`** antes de cerrar el brief (WCAG 2.1 AA: contraste, toque ≥ 44 px, teclado, lector de pantalla).
- **Textos con `design:ux-copy`**: español de Panamá, formal y breve. Ningún error técnico visible al usuario (nada de stack traces, códigos HTTP, nombres de campos ni mensajes crudos de proveedor); siempre un mensaje claro con qué hacer a continuación.
- **Flujo reanudable**: todo flujo de varios pasos guarda el avance por paso y se retoma con OTP desde el último paso incompleto (Prompt Maestro §19).
- **Prueba en celular real** por Gianclaudio antes de aprobar cada brief de UI; no se cierra solo con capturas.
- **Sesión de diseño**: con Gianclaudio, no con Diego. Las 5 pantallas clave se preparan en HTML con los tokens FIC (`styles/tokens.css`) al cierre del Brief 01 para revisarlas en celular; lo aprobado se congela en `docs/design/` antes del Brief 02.

## Marca
`--fic-azul #193A76` · `--fic-azul-claro #66A5E6`. Sobrio, sin gradientes. Detalle en §15 y §19 del Prompt Maestro.
