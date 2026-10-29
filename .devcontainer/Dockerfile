# Python 3.12.14 + Debian bookworm build tools, amd64 manifest pinned by digest.
FROM python:3.12.14-bookworm@sha256:c90be507635af19768837aa7eeb2f4ce89a74d62962a335497b9df8edfb7f19d
WORKDIR /work
COPY tools/requirements.txt /tmp/goosecraft-requirements.txt
# Cloud proxy trust is supplied at build time, never embedded in image layers.
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then \
      PIP_CERT=/run/secrets/proxy_ca python -m pip install --no-cache-dir -r /tmp/goosecraft-requirements.txt; \
    else \
      python -m pip install --no-cache-dir -r /tmp/goosecraft-requirements.txt; \
    fi
COPY tools/bootstrap.py tools/bootstrap.py
COPY toolchain.lock.json toolchain.lock.json
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then \
      GIT_SSL_CAINFO=/run/secrets/proxy_ca python tools/bootstrap.py --jobs 2; \
    else \
      python tools/bootstrap.py --jobs 2; \
    fi
COPY . .
CMD ["python", "tools/project.py", "test"]
