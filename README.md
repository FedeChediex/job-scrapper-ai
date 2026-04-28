# Job Scraper con Análisis de IA

Automatización end-to-end que scrapea ofertas de trabajo de LinkedIn, filtra duplicados y títulos irrelevantes, y analiza cada oferta con IA para evaluar el match con tu perfil. Los resultados se guardan en Google Sheets evitando registros repetidos.

## ¿Qué hace?

1. **Disparo manual** — se ejecuta desde el botón "Execute workflow" en n8n
2. **Define parámetros de búsqueda** — lee los términos desde `SEARCH_QUERIES` y los separa en ítems individuales (Split Out)
3. **Scrapea LinkedIn** — hace una petición POST a Apify por cada término de búsqueda, obteniendo hasta 10 ofertas por término
4. **Espera el scraping** — aguarda 15 segundos para que Apify complete el run
5. **Obtiene los resultados** — consulta el dataset del run usando el `runId` devuelto por Apify
6. **Deduplica** — aplana y elimina ofertas repetidas por `id` entre distintos términos de búsqueda
7. **Compara con el sheet** — lee los links ya guardados en Google Sheets y filtra solo las ofertas nuevas
8. **Filtra por título** — descarta ofertas cuyos títulos coincidan con `EXCLUDED_TITLES`
9. **Procesa en batches de 10** — itera de a 10 ofertas para no saturar la API de Gemini
10. **Analiza con IA** — envía cada oferta a Gemini 2.5 Flash Lite con el perfil de Federico, obteniendo un JSON con título, empresa, requisitos, modalidad, nivel, puntaje (0-10) y razón
11. **Limpia el JSON** — parsea la respuesta de Gemini, elimina backticks y normaliza el puntaje si viene en escala 0-100
12. **Guarda en Google Sheets** — hace append/update usando el link como clave única para evitar duplicados
13. **Espera entre batches** — aguarda 65 segundos entre cada batch para respetar los rate limits de Gemini

## Flujo de nodos

```
Manual Trigger
  ├── Definir parametros busqueda → Split Out → Peticion Scrapping → RunID → Wait (15s)
  │                                                                              │
  │                                                                     Obtencion resultados
  │                                                                              │
  │                                                                     Deduplicar busqueda
  │                                                                              │
  └── ObtenerDatosSheet ──────────────────────────────────────────────── Merge
                                                                              │
                                                                    Filtrar nuevos trabajos
                                                                              │
                                                                    Filtrar por titulo (EXCLUDED_TITLES)
                                                                              │
                                                                    Loop Over Items (batch 10)
                                                                         ├── Analizar trabajos con IA → Wait1 (65s) ↩
                                                                         └── Limpiar JSON → Agregar Trabajos a Google Sheets
```

## Stack

- **n8n** — orquestación del flujo (instalación local npm en WSL)
- **Apify** — scraping de LinkedIn Jobs (`curious_coder~linkedin-jobs-scraper`)
- **Gemini 2.5 Flash Lite** — análisis de ofertas con IA
- **Google Sheets API** — almacenamiento de resultados con deduplicación por link
- **JavaScript** — lógica de filtrado, deduplicación y limpieza de datos

## Estructura del proyecto

```
/
├── Workflow.json     # Workflow importable en n8n
├── .env              # Variables de entorno (no subir a git)
├── start.sh          # Script de inicio que carga el .env
└── README.md
```

## Configuración

### 1. Variables de entorno

Completá el `.env` con tus credenciales:

```env
GENERIC_TIMEZONE=America/Argentina/Buenos_Aires
N8N_BLOCK_ENV_ACCESS_IN_NODE=false

APIFY_TOKEN=tu_token_de_apify
GEMINI_API_KEY=tu_api_key_de_gemini
GOOGLE_SHEET_URL=url_completa_de_tu_google_sheet
GOOGLE_SHEET_NAME=nombre_de_la_hoja

SEARCH_QUERIES='Lista de trabajos. Ej: docente, contador'
EXCLUDED_TITLES='Lista de trabajos excluidos de la busqueda. Ej: sales,account executive,head of sales'
```

> Los valores con espacios o comas van entre comillas simples. 

### 2. Google Sheets

Creá una hoja con estas columnas exactas (respetando mayúsculas):

| Titulo | Empresa | Modalidad | Nivel | Puntaje | Razon | Link |
|--------|---------|-----------|-------|---------|-------|------|

Configurá las credenciales OAuth2 de Google Sheets en n8n antes de ejecutar.

### 3. Iniciar n8n

```bash
chmod +x start.sh   # solo la primera vez
./start.sh
```

El script carga el `.env`, verifica la configuración y arranca n8n.

### 4. Importar el workflow

1. Abrí n8n en `http://localhost:5678`
2. Menú → Import workflow → seleccioná `Workflow.json`

## Columnas guardadas en Google Sheets

| Columna | Descripción |
|---------|-------------|
| Titulo | Título del puesto |
| Empresa | Nombre de la empresa |
| Modalidad | Remoto / Híbrido / Presencial |
| Nivel | Junior / Semi-senior / Senior |
| Puntaje | Score 0-10 de match con el perfil |
| Razon | Justificación del puntaje dada por la IA |
| Link | URL de la oferta (clave única para evitar duplicados) |

## Notas técnicas

- El `runId` de Apify se obtiene dinámicamente desde la respuesta de "Peticion Scrapping" (`$json.data.id`) — no está hardcodeado.
- La deduplicación ocurre en dos niveles: por `id` entre términos de búsqueda (nodo "Deduplicar busqueda") y por `link` contra el sheet existente (nodo "Filtrar nuevos trabajos").
- El puntaje de Gemini se normaliza automáticamente: si viene en escala 0-100, se divide por 10.
- El delay de 65s entre batches evita errores 429 (rate limit) de la API de Gemini.
- `$env.X` en nodos Code requiere `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`. Los errores de TypeScript en el editor son visuales y no afectan la ejecución.
