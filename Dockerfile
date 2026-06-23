FROM python:3.12-slim

WORKDIR /app

# Instalar dependencias de compilación ANTES de pip install
# Necesario para pyswisseph, psycopg2-binary, y otras extensiones C
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements
COPY requirements.txt .

# Instalar Python deps (compila pyswisseph aquí en FS writable)
RUN pip install --no-cache-dir -r requirements.txt

# Copiar aplicación
COPY . .

# Puerto para Railway
EXPOSE 8000

# Solo Uvicorn
WORKDIR /app/arcanum-api
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
