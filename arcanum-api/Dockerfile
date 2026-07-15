# Build DESDE LA RAIZ del repo (para tomar la lista unica de requirements):
#   docker build -f arcanum-api/Dockerfile -t arcanum-api .
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY arcanum-api/ .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
