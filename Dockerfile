# ── Stage 1: Build & test ──────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

COPY app/ ./app/
COPY tests/ ./tests/

RUN python -m pytest tests/ -v --tb=short

# ── Stage 2: Production image ───────────────────────────────────────────────
FROM python:3.12-slim AS production

LABEL maintainer="your-name"
LABEL project="fintrack"
LABEL version="1.0.0"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DB_PATH=/data/fintrack.db

RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local
COPY app/ .

RUN mkdir -p /data && chown -R appuser:appuser /app /data

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
