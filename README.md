# Job Scraper con Análisis de IA

Automatización end-to-end que scrapea ofertas de trabajo de LinkedIn y las analiza con IA para evaluar el match con tu perfil.

## ¿Qué hace?

1. Scrapea ofertas de LinkedIn según un término de búsqueda y ubicación (ej: "trainee node.js Buenos Aires")
2. Analiza cada oferta con Gemini (LLM) evaluando qué tan apto sos para el puesto
3. Guarda los resultados estructurados en Google Sheets con título, empresa, requisitos, modalidad, nivel, puntaje y razón

## Stack

- **n8n** — orquestación del flujo
- **Apify** — scraping de LinkedIn Jobs
- **Gemini API** — análisis de ofertas con IA
- **Google Sheets API** — almacenamiento de resultados
- **JavaScript** — lógica de procesamiento y limpieza de datos

## Configuración

1. Importá `Workflow.json` en n8n
2. Reemplazá las variables:
   - `YOUR_APIFY_TOKEN` → tu token de Apify
   - `YOUR_GEMINI_API_KEY` → tu API key de Gemini
   - `YOUR_GOOGLE_SHEET_URL` → URL de tu hoja de cálculo
   - `YOUR_RUN_ID` → ID del run de Apify (ver nota abajo)
   > **Nota:** El campo `YOUR_RUN_ID` está hardcodeado temporalmente. 
   > Para obtenerlo dinámicamente, el nodo "Obtencion resultados" debería 
   > leer el `id` que devuelve "Peticion Scrapping" usando `{{ $('Peticion Scrapping').item.json.id }}`.
   > Esta mejora está pendiente de implementar.
3. Configurá las credenciales de Google Sheets en n8n
4. Ejecutá el workflow

