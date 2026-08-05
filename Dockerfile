# AS builder: this stage is used to build the dependencies and create a virtual environment. It uses the official Python 3.11 slim image as the base image.
FROM python:3.11-slim-trixie AS builder

# The WORKDIR instruction sets the working directory for any RUN, CMD, ENTRYPOINT, COPY, and ADD instructions that follow in the Dockerfile. If the directory does not exist, it will be created.
WORKDIR /app

# The COPY instruction copies new files or directories from <src> and adds them to the filesystem of the container at the path <dest>. 
# In this case, it copies the requirements.txt file to the /app directory in the container.
COPY requirements.txt .

# The RUN instruction will execute any commands in a new layer on top of the current image and commit the results.
# In this case, it creates a new virtual environment in the /opt/venv directory. 
# This is done to isolate the Python dependencies from the system Python and to make it easier to copy just the virtual environment into the final image in stage 2.
RUN python -m venv /opt/venv

# The ENV instruction sets the environment variable PATH to include the bin directory of the virtual environment.
# This ensures that when we run python or pip commands, they will use the versions in the virtual environment rather than the system versions.
ENV PATH="/opt/venv/bin:$PATH"


# The RUN instruction installs the Python dependencies listed in requirements.txt into the virtual environment.
# The --no-cache-dir option tells pip not to store the downloaded packages in its cache, which helps to keep the image size smaller.
RUN pip install --no-cache-dir -r requirements.txt



# AS final: this stage is used to create the final image that will be used in production. It also uses the official Python 3.11 slim image as the base image.
# This stage is separate from the builder stage to ensure that the final image is as small and clean as possible, containing only the necessary runtime dependencies and application code.
FROM python:3.11-slim-trixie


WORKDIR /app

# Copies ONLY the finished virtualenv from stage 1 into this clean image. This is the entire point of multi-stage builds:
# we get the result of the dependency install without any of the tooling that produced it.
COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
# Same reasoning as stage 1 — make sure `python` resolves to the venv's interpreter (with our installed packages) at runtime.


# Creates a dedicated non-root user with an EXPLICIT numeric UID (1000), not just a name. 
# Kubernetes securityContext.runAsUser needs a specific UID to enforce — an auto-assigned UID would be unpredictable and couldn't be pinned in the pod spec.
# -s /usr/sbin/nologin: this user can't get an interactive shell. -M: don't create a home directory — this user never needs one.
RUN groupadd -g 1000 appgroup && useradd -u 1000 -g appgroup -s /usr/sbin/nologin -M appuser


# The COPY instruction copies the application code from the host machine into the container.
# It copies the api directory from the host machine to the /app/api directory in the container.
COPY api ./api

# From this line onward, and for the container at runtime, every process runs as UID 1000, not root. If this container is ever compromised, the attacker doesn't get root inside it.
USER appuser

# Documentation only — does NOT actually open the port. Included here for clarity/tooling; Kubernetes ignores it entirely and routes traffic based on the container's actual listening port.
EXPOSE 8000

# Runs uvicorn on port 8000 (not 80) — a non-root user (UID 1000) cannot bind to privileged ports below 1024. The Kubernetes Service will map the external port 80 -> this container's 8000
CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--timeout-keep-alive", "10"]
