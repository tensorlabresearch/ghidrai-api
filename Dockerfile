FROM gradle:8.10.2-jdk21-jammy AS build

USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    make \
    patch \
    python3 \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

ARG GHIDRAI_REPO=https://github.com/mattfj10/ghidrAI.git
ARG GHIDRAI_REF=9e33b0bd83c90abfe442f1002d0a7d5711493bd9

WORKDIR /src
RUN git clone "${GHIDRAI_REPO}" . \
    && git checkout "${GHIDRAI_REF}"

COPY docker/patches/bind-host.patch /tmp/bind-host.patch
RUN git apply /tmp/bind-host.patch

ENV JAVA_HOME=/opt/java/openjdk
ENV GRADLE_USER_HOME=/home/gradle/.gradle

RUN if [ ! -d /src/dependencies/flatRepo ]; then \
      gradle --no-daemon -p /src -I gradle/support/fetchDependencies.gradle help; \
    fi
RUN gradle --no-daemon -p /src prepDev
RUN gradle --no-daemon -p /src assemble

FROM eclipse-temurin:21-jdk-jammy AS runtime

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    libxi6 \
    libxrender1 \
    libxtst6 \
    procps \
    unzip \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 ghidra \
    && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ghidra \
    && mkdir -p /data /home/gradle/.gradle \
    && ln -s /opt/ghidrai /src

ENV GHIDRA_REPO=/opt/ghidrai
ENV GHIDRA_ELECTRON_HOST=0.0.0.0
ENV GHIDRA_ELECTRON_PORT=8089
ENV GHIDRA_ELECTRON_DATA_DIR=/data
ENV GHIDRA_MAXMEM=2G
ENV GRADLE_USER_HOME=/home/gradle/.gradle

WORKDIR /opt/ghidrai

COPY --from=build --chown=10001:10001 /home/gradle/.gradle /home/gradle/.gradle
COPY --from=build --chown=10001:10001 /src /opt/ghidrai
COPY --chown=10001:10001 docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R 10001:10001 /data /home/gradle /opt/ghidrai

USER 10001:10001

VOLUME ["/data"]
EXPOSE 8089

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
