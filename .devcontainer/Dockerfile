# Python 3.12.14 + Debian bookworm build tools, amd64 manifest pinned by digest.
FROM python:3.12.14-bookworm@sha256:c90be507635af19768837aa7eeb2f4ce89a74d62962a335497b9df8edfb7f19d AS toolchain
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
FROM toolchain AS graphics
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then \
      GIT_SSL_CAINFO=/run/secrets/proxy_ca python tools/bootstrap.py --graphics --jobs 2; \
    else python tools/bootstrap.py --graphics --jobs 2; fi
# An immutable Debian snapshot supplies X11 development files and software Vulkan.
RUN --mount=type=secret,id=proxy_ca,mode=0444 \
    rm -f /etc/apt/sources.list.d/* && \
    echo 'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20261020T000000Z bookworm main' > /etc/apt/sources.list && \
    if [ -f /run/secrets/proxy_ca ]; then \
      echo 'Acquire::https::CaInfo "/run/secrets/proxy_ca";' > /tmp/goosecraft-apt.conf; \
    else touch /tmp/goosecraft-apt.conf; fi && \
    apt-get -c /tmp/goosecraft-apt.conf update && \
    apt-get -c /tmp/goosecraft-apt.conf install -y --no-install-recommends \
      libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev \
      libxss-dev libxtst-dev libxkbcommon-dev libxkbcommon-x11-dev \
      xvfb xauth libvulkan1 mesa-vulkan-drivers vulkan-tools && \
    rm -rf /var/lib/apt/lists/* /tmp/goosecraft-apt.conf
COPY . .
CMD ["python", "tools/project.py", "render-test"]

FROM toolchain AS headless
COPY . .
CMD ["python", "tools/project.py", "test"]
