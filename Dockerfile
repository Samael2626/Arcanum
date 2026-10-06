# Dockerfile UNICO de ARCANUM API — lo usan Railway y Render (render.yaml apunta
# aqui via dockerfilePath). El arranque (migraciones si/no) lo decide start.sh
# segun RUN_MIGRATIONS. Build context = raiz del repo.
FROM python:3.12-slim

WORKDIR /app

# Dependencias de compilacion ANTES de pip install (pyswisseph, psycopg2, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Lista unica de requirements (raiz del repo)
COPY requirements.txt .
RUN python -m pip install --no-cache-dir pip==26.2.1 \
    && python -m pip install --no-cache-dir -r requirements.txt

# Solo el backend y su arranque. El repo local contiene la firma Android.
COPY arcanum-api/ ./arcanum-api/
COPY start.sh ./

EXPOSE 8000

# Entrypoint unico Railway/Render. Migraciones on/off via RUN_MIGRATIONS.
CMD ["sh", "/app/start.sh"]
