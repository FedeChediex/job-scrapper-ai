# Job Scraper con Análisis de IA

Automatización end-to-end que scrapea ofertas de trabajo de LinkedIn, filtra duplicados y títulos irrelevantes, y analiza cada oferta con IA para evaluar el match con tu perfil. Los resultados se guardan en Google Sheets evitando registros repetidos.

---

## ¿Qué hace?

1. **Disparo manual** — se ejecuta desde el botón "Execute workflow" en n8n
2. **Define parámetros de búsqueda** — lee los términos desde `SEARCH_QUERIES` y los separa en ítems individuales
3. **Scrapea LinkedIn** — hace una petición a Apify por cada término de búsqueda, obteniendo hasta 10 ofertas por término
4. **Espera el scraping** — aguarda 15 segundos para que Apify complete el run
5. **Obtiene los resultados** — consulta el dataset del run usando el `runId` devuelto por Apify
6. **Deduplica por búsqueda** — aplana y elimina ofertas repetidas por `id` entre distintos términos de búsqueda
7. **Filtra contra historial** — lee la hoja `Seen` y descarta cualquier oferta que la API haya traído alguna vez, evitando re-evaluaciones innecesarias
8. **Guarda en historial** — registra el `id` de cada oferta nueva en la hoja `Seen` antes de cualquier otro filtro
9. **Filtra por título** — descarta ofertas cuyos títulos coincidan con `EXCLUDED_TITLES` (incluye roles Senior, Semi Senior, SSR y otros no relevantes)
10. **Limita resultados** — procesa hasta `MAX_RESULTS` ofertas por ejecución (límite de Gemini)
11. **Analiza con IA** — envía cada oferta a Gemini con el perfil del candidato, obteniendo un JSON con título, empresa, modalidad, nivel, puntaje (0-10) y razón
12. **Limpia el JSON** — parsea la respuesta de Gemini y normaliza el puntaje si viene en escala 0-100
13. **Guarda en Google Sheets** — hace append/update en la hoja `Evaluated` usando el link como clave única
14. **Espera entre batches** — aguarda entre cada batch para respetar los rate limits de Gemini

---

## Criterios de puntaje (IA)

| Puntaje | Criterio |
|---------|----------|
| 9-10 | Rol junior/trainee/intern en automatización (RPA, n8n, workflows) o IA (agentes, LLMs, integración), stack alineado |
| 7-8 | Rol junior/trainee/intern en automatización o IA aunque el stack no sea perfecto, o rol de IoT/robótica/sistemas embebidos |
| 5-6 | Rol accesible pero no relacionado con automatización ni IA (ej: frontend puro, backend genérico) |
| 3-4 | Mid-Level/Senior, o dominio muy distante (ej: data science clásico sin automatización) |
| 1-2 | No aplica en absoluto (ventas, auditoría, RRHH, docencia, soporte, etc.) |

> **Regla principal:** se prioriza que el ROL esté en el dominio de automatización o IA por encima del match de stack tecnológico.

---

## Stack

- **n8n** — orquestación del flujo (instalación local npm en WSL)
- **Apify** — scraping de LinkedIn Jobs (`curious_coder~linkedin-jobs-scraper`)
- **Gemini 2.5 Flash Lite** — análisis de ofertas con IA
- **Google Sheets API** — almacenamiento de resultados con deduplicación por link

---

## Estructura del proyecto

```
/
├── Workflow.json     # Workflow importable en n8n
├── .env              # Variables de entorno con tus credenciales (no se sube a git)
├── .env.example      # Template de variables de entorno (sin credenciales reales)
├── start.sh          # Script de inicio que carga el .env
└── README.md
```

---

## Guía de instalación paso a paso

### Requisitos previos

Antes de empezar necesitás tener instalado:

- **Windows con WSL** (Windows Subsystem for Linux) — [guía oficial de Microsoft](https://learn.microsoft.com/es-es/windows/wsl/install)
- **Node.js** dentro de WSL — instalalo con `sudo apt install nodejs npm` en la terminal de WSL
- **n8n** — se instala en el paso 2

Si no sabés qué es WSL: es una forma de correr Linux dentro de Windows sin instalar nada extra. Abrís "Ubuntu" o "Debian" desde el menú inicio y tenés una terminal de Linux.

---

### Paso 1: Clonar el repositorio

Abrí una terminal WSL y ejecutá:

```bash
git clone https://github.com/tu-usuario/job-scrapper-ai.git
cd job-scrapper-ai
```

---

### Paso 2: Instalar n8n

```bash
npm install -g n8n
```

Esto puede tardar unos minutos. Una vez terminado, n8n queda instalado globalmente.

---

### Paso 3: Crear las cuentas necesarias

Necesitás crear cuentas gratuitas en estos servicios:

**Apify** (para scrapear LinkedIn)
1. Entrá a [apify.com](https://apify.com) y creá una cuenta gratuita
2. Una vez dentro, andá a *Settings → Integrations → API tokens*
3. Copiá tu token — lo vas a necesitar en el `.env`

**Google Cloud** (para guardar resultados en Sheets)
1. Entrá a [console.cloud.google.com](https://console.cloud.google.com) y creá un proyecto nuevo
2. Buscá "Google Sheets API" y habilitala
3. Andá a *APIs & Services → Credentials → Create credentials → OAuth 2.0 Client ID (ID de cliente de OAuth)* Va a pedir configurar la plantilla, hacerlo con tus datos.
4. Tipo de aplicacion, escritorio.
5. Descargá el archivo de credenciales JSON — lo vas a configurar en n8n

**Google AI Studio** (para el análisis con Gemini)
1. Entrá a [aistudio.google.com](https://aistudio.google.com)
2. Andá a *Get API key → Create API key*
3. Copiá la key — la vas a necesitar en el `.env`

---

### Paso 4: Crear el Google Sheet

1. Abrí [Google Sheets](https://sheets.google.com) y creá una nueva hoja de cálculo
2. Renombrá la primera hoja como `Evaluated`
3. Creá una segunda hoja y renombrala `Pending`
4. Creá una tercera hoja y renombrala `Seen`
5. En la hoja `Evaluated`, escribí estas columnas en la fila 1 (respetando mayúsculas y espacios exactos):

| Titulo   | Empresa | Modalidad | Nivel | Puntaje | Razon | Link | APLIQUE |
|----------|---------|-----------|-------|---------|-------|------|---------|

6. En la hoja `Pending`, escribí estas columnas en la fila 1:

| Id | title | companyName | link | descriptionText |
|----|-------|-------------|------|-----------------|

7. En la hoja `Seen`, escribí esta columna en la fila 1:

| Id |
|----|

8. Copiá la URL completa del sheet — la vas a necesitar en el `.env`

---

### Paso 5: Configurar el archivo `.env`

En la carpeta del proyecto hay un archivo llamado `.env.example`. Copialo con el nombre `.env` y completá los valores con tus credenciales:

```bash
cp .env.example .env
```

```env
GENERIC_TIMEZONE=America/Argentina/Buenos_Aires
N8N_BLOCK_ENV_ACCESS_IN_NODE=false

APIFY_TOKEN=tu_token_de_apify
GEMINI_API_KEY=tu_api_key_de_gemini
GOOGLE_SHEET_URL=url_completa_de_tu_google_sheet

GOOGLE_SHEET_EVALUATED=Evaluated
GOOGLE_SHEET_PENDING=Pending
GOOGLE_SHEET_SEEN=Seen

SEARCH_QUERIES='RPA developer junior,process automation junior,AI automation developer,n8n developer,workflow automation'

EXCLUDED_TITLES='sales,account executive,head of sales,pre sales,panda3d,auditor,contador,cuentas a pagar,mlops,docente'

CANDIDATE_NAME="Tu Nombre Completo"
CANDIDATE_PROFILE="Tu perfil: edad, ubicación, estudios, stack tecnológico, intereses, nivel de inglés. Ejemplo: 22 años, Buenos Aires. Estudiante de Ingeniería en Sistemas (3er año). Stack: JavaScript, Node.js, React, SQL, Git. Intereses: automatización e IA. Inglés intermedio."

MAX_RESULTS=20
```

> **Nota:** Los valores con comas o espacios van entre comillas simples. El `CANDIDATE_PROFILE` va entre comillas dobles. 
 
### Personalizar las búsquedas

Para cambiar qué trabajos busca, editá el archivo `.env`:

- **`SEARCH_QUERIES`** — los términos que se buscan en LinkedIn, separados por comas. Cuantos más términos, más trabajos encuentra (y más tarda)
- **`EXCLUDED_TITLES`** — palabras que, si aparecen en el título del trabajo, lo descartan antes de analizarlo con IA. Útil para ahorrar tokens
- **`CANDIDATE_PROFILE`** — descripción del candidato que usa Gemini para evaluar el match. Cuanto más detallado, mejor el análisis
- **`MAX_RESULTS`** — máximo de trabajos que se analizan con IA por ejecución (el límite por el plan gratuito de Gemini es 20)

---

### Paso 6: Iniciar n8n

En la terminal WSL, dentro de la carpeta del proyecto:

```bash
chmod +x start.sh   # solo la primera vez
./start.sh
```

Esto carga el `.env` y arranca n8n. Vas a ver un mensaje indicando que n8n está corriendo. No cierres esta terminal mientras usás el workflow.

---

### Paso 7: Importar el workflow en n8n

1. Abrí tu navegador y andá a [http://localhost:5678](http://localhost:5678)
2. Creá una cuenta (solo la primera vez, es local)
3. En el menú lateral, hacé click en *Workflows*
4. Click en el botón de los tres puntos (⋯) → *Import from file*
5. Seleccioná el archivo `Workflow.json` de este proyecto
6. El workflow debería aparecer con todos los nodos conectados

---

### Paso 8: Configurar las credenciales de Google Sheets en n8n

1. En n8n, andá a *Entrar a un Nodo excel → Credential → New credential*
2. Buscá "Google Sheets OAuth2 API"
3. Ingresá las credenciales (Client ID, Client secret) del archivo JSON que descargaste en el Paso 3
4. Guardá y autorizá el acceso a tu cuenta de Google, vas a tener que iniciar sesion con google
5. Seleccioná la credencial que acabás de crear en el nodo

---

## Cómo usar el workflow

### Ejecutar manualmente

1. Abrí n8n en [http://localhost:5678](http://localhost:5678)
2. Abrí el workflow importado
3. Hacé click en el botón **"Execute workflow"** (arriba a la derecha)
4. Esperá — el proceso completo tarda entre 5 y 15 minutos dependiendo de cuántos trabajos encuentre
5. Cuando termine, abrí tu Google Sheet y revisá la hoja `Evaluated`

### Entender los resultados

La hoja `Evaluated` tiene estas columnas:

| Columna | Qué significa |
|---------|---------------|
| Titulo | Título del puesto según LinkedIn |
| Empresa | Nombre de la empresa |
| Modalidad | Remoto / Híbrido / Presencial |
| Nivel | Junior / Mid-Level / Senior (la experiencia que pide la oferta) |
| Puntaje | Score del 1 al 10 de qué tan afín es al perfil |
| Razon | Explicación de por qué la IA le asignó ese puntaje |
| Link | URL directa a la oferta en LinkedIn |
| APLIQUE | Podés completarlo vos a mano (Sí/No/Pendiente) |

**Recomendación:** ordená el sheet por la columna "Puntaje" de mayor a menor para ver primero las mejores oportunidades.



Después de editar el `.env`, reiniciá n8n con `./start.sh` para que tome los cambios.

---

## Notas técnicas

- El `runId` de Apify se obtiene dinámicamente desde la respuesta del scraper — no está hardcodeado
- La deduplicación ocurre en dos niveles: por `id` entre términos de búsqueda dentro de la misma ejecución, y por `id` contra la hoja `Seen` que acumula todo el historial
- La hoja `Seen` registra **toda** oferta que la API haya traído alguna vez, sin importar si fue evaluada, filtrada por título o descartada por cualquier otro motivo — esto evita reprocesar trabajos en ejecuciones futuras
- El puntaje de Gemini se normaliza automáticamente: si viene en escala 0-100, se divide por 10
- El delay entre batches evita errores 429 (rate limit) de la API de Gemini
- Los trabajos que superan `MAX_RESULTS` se guardan en la hoja `Pending` y se procesan en la próxima ejecución
- `$env.X` en nodos Code requiere `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`
