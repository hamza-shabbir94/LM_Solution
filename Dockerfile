FROM python:3.14.6-slim-trixie

WORKDIR /app

COPY requirements.txt .

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.14.6-slim-trixie
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN groupadd -g 1000 appgroup && useradd -u 1000 -g appgroup -s /usr/sbin/nologin -M appuser

COPY api ./api

USER appuser

CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8080", "--timeout-keep-alive", "10"]
