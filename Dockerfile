# --- Stage 1: builder ---------------------------------------------------------
# Installs Python dependencies into an isolated virtualenv that we'll copy
# wholesale into the runtime stage. Build tools and pip caches stay behind.
FROM python:3.12-slim AS builder

RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

WORKDIR /build
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# --- Stage 2: runtime ---------------------------------------------------------
# Fresh base image. We only inherit the venv from the builder — none of the
# build-time state (pip's metadata, downloaded tarballs, etc.) comes along.
FROM python:3.12-slim

# Non-root user with explicit UID/GID. Numeric values matter for Kubernetes
# SecurityContext and for filesystem permission audits.
RUN groupadd --system --gid 1001 appgroup && \
    useradd --system --uid 1001 --gid appgroup --no-create-home appuser

COPY --from=builder /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

WORKDIR /app
COPY --chown=appuser:appgroup app/main.py app/__init__.py ./

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()" || exit 1

CMD ["python", "main.py"]
