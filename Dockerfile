# ============================================================
# STAGE 1: "builder" — installs dependencies only.
# This stage exists purely to produce a populated virtualenv.
# Everything in this stage (pip cache, this whole layer) is
# thrown away once the final image is built — it never ships.
# ============================================================
FROM python:3.11-slim-trixie AS builder
# AS builder gives this stage a name, so stage 2 can reference
# it later with `COPY --from=builder`. Without this name, that
# COPY --from instruction would fail with "stage not found".

WORKDIR /app
# Sets the working directory for all following instructions in
# THIS stage. WORKDIR does not carry over to the next stage —
# each FROM starts a completely fresh filesystem.

COPY requirements.txt .
# Copy ONLY the dependency manifest first, not the whole app.
# Docker caches each layer; as long as requirements.txt is
# unchanged, this layer (and the expensive pip install below)
# is reused on rebuilds instead of re-run from scratch.

RUN python -m venv /opt/venv
# Create an isolated virtual environment at a fixed, known path.
# This lets us copy just this one folder into the final image
# in stage 2, instead of copying Python's entire site-packages.

ENV PATH="/opt/venv/bin:$PATH"
# Puts the venv's `python` and `pip` first on PATH, so the next
# RUN (and any Python invocation after this) uses the venv, not
# the system Python.

RUN pip install --no-cache-dir -r requirements.txt
# Installs dependencies into the venv. --no-cache-dir stops pip
# from storing its download cache on disk — irrelevant here since
# this whole stage gets discarded, but a good habit either way.


# ============================================================
# STAGE 2: final runtime image — this is what actually ships
# and runs in production/Kubernetes.
# ============================================================
FROM python:3.11-slim-trixie
# Fresh, clean base image. None of the pip cache, build tooling,
# or intermediate files from the builder stage exist here unless
# explicitly copied in below.

WORKDIR /app
# Must be re-declared — WORKDIR does not persist across stages.

COPY --from=builder /opt/venv /opt/venv
# Copies ONLY the finished virtualenv from stage 1 into this
# clean image. This is the entire point of multi-stage builds:
# we get the *result* of the dependency install without any of
# the tooling that produced it.

ENV PATH="/opt/venv/bin:$PATH"
# Same reasoning as stage 1 — make sure `python` resolves to the
# venv's interpreter (with our installed packages) at runtime.

RUN groupadd -g 1000 appgroup && useradd -u 1000 -g appgroup -s /usr/sbin/nologin -M appuser
# Creates a dedicated non-root user with an EXPLICIT numeric UID
# (1000), not just a name. Kubernetes securityContext.runAsUser
# needs a specific UID to enforce — an auto-assigned UID would be
# unpredictable and couldn't be pinned in the pod spec.
# -s /usr/sbin/nologin: this user can't get an interactive shell.
# -M: don't create a home directory — this user never needs one.

COPY api ./api
# Copy only the application code needed to run the service —
# not the README, tests, or .git — keeping the image minimal and
# avoiding unrelated file changes invalidating this cache layer.

USER appuser
# From this line onward, and for the container at runtime, every
# process runs as UID 1000, not root. If this container is ever
# compromised, the attacker doesn't get root inside it.

EXPOSE 8080
# Documentation only — does NOT actually open the port. Included
# here for clarity/tooling; Kubernetes ignores it entirely and
# routes traffic based on the container's actual listening port.

CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--timeout-keep-alive", "10"]
# Runs uvicorn on port 8000 (not 80) — a non-root user (UID 1000)
# cannot bind to privileged ports below 1024. The Kubernetes
# Service will map the external port 80 -> this container's 8000