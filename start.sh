ENV_FILE="$(dirname "$0")/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌  No se encontró el archivo .env en: $ENV_FILE"
  echo "    Crealo con tus API keys antes de continuar."
  exit 1
fi
 
if ! command -v n8n &> /dev/null; then
  echo "❌  n8n no está instalado o no está en el PATH."
  echo "    Instalalo con: npm install -g n8n"
  exit 1
fi
 
# --- Cargar variables de entorno ------------------------------
 
echo "✅  Cargando variables desde $ENV_FILE ..."
 
set -a              # exporta automáticamente todas las variables que se definan
source "$ENV_FILE"
set +a              # desactiva el export automático
 
export N8N_BLOCK_ENV_ACCESS_IN_NODE=false
 
# --- Verificar configuración ----------------------------------
 
echo ""
echo "🔍  Verificando configuración:"
echo "    N8N_BLOCK_ENV_ACCESS_IN_NODE = $N8N_BLOCK_ENV_ACCESS_IN_NODE"
 
if [ "$N8N_BLOCK_ENV_ACCESS_IN_NODE" = "false" ]; then
  echo "✅  Acceso a \$env habilitado en workflows."
else
  echo "⚠️   Advertencia: acceso a \$env NO habilitado."
fi

# Mostrar qué variables se cargaron (solo los nombres, no los valores)
echo "    Variables cargadas:"
grep -v '^\s*#' "$ENV_FILE" | grep '=' | while IFS='=' read -r key _; do
  echo "      · $key"
done
 
# --- Iniciar n8n ----------------------------------------------
 
echo ""
echo "🚀  Iniciando n8n..."
echo "------------------------------------------------------------"
 
n8n start