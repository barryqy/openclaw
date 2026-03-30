# syntax=docker/dockerfile:1.7

FROM node:24-bookworm-slim

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000
ARG OPENCLAW_VERSION=2026.3.24
ARG DEFENSECLAW_VERSION=0.2.0

ENV DEBIAN_FRONTEND=noninteractive
ENV npm_config_update_notifier=false
ENV npm_config_fund=false
ENV npm_config_audit=false
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    less \
    procps \
    python3 \
    python3-venv \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN existing_group="$(getent group "${USER_GID}" | cut -d: -f1 || true)" \
  && if [ -n "${existing_group}" ]; then \
       target_group="${existing_group}"; \
     else \
       target_group="${USERNAME}"; \
       groupadd --gid "${USER_GID}" "${target_group}"; \
     fi \
  && existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1 || true)" \
  && if [ -n "${existing_user}" ]; then \
       target_user="${existing_user}"; \
       target_home="$(getent passwd "${existing_user}" | cut -d: -f6)"; \
     else \
       target_user="${USERNAME}"; \
       useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${target_user}"; \
       target_home="/home/${target_user}"; \
     fi \
  && mkdir -p /workspace "${target_home}" \
  && chown -R "${USER_UID}:${USER_GID}" /workspace "${target_home}" \
  && printf '%s\n' "${target_user}" > /tmp/openclaw-target-user \
  && printf '%s\n' "${target_home}" > /tmp/openclaw-target-home

ENV HOME=/home/${USERNAME}
ENV OPENCLAW_HOME=/home/${USERNAME}
ENV OPENCLAW_STATE_DIR=/home/${USERNAME}/.openclaw
ENV DEFENSECLAW_HOME=/home/${USERNAME}/.defenseclaw
ENV PATH=/home/${USERNAME}/.local/bin:/home/${USERNAME}/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN printf '%s\n' \
  'export PATH="/home/developer/.local/bin:/home/developer/.cargo/bin:$PATH"' \
  > /etc/profile.d/openclaw-path.sh

COPY docker/entrypoint.sh /usr/local/bin/openclaw-defenseclaw-entrypoint
COPY docker/openclaw-setup.sh /usr/local/bin/openclaw-setup

RUN chmod +x /usr/local/bin/openclaw-defenseclaw-entrypoint /usr/local/bin/openclaw-setup

RUN npm install -g "openclaw@${OPENCLAW_VERSION}"

RUN target_user="$(cat /tmp/openclaw-target-user)" \
  && target_home="$(cat /tmp/openclaw-target-home)" \
  && ln -sfn "${target_home}" "/home/${USERNAME}" \
  && mkdir -p "${target_home}/.local/bin" "${target_home}/.cargo/bin" \
  && chown -R "${USER_UID}:${USER_GID}" "/home/${USERNAME}" "${target_home}"

USER ${USER_UID}:${USER_GID}
WORKDIR /home/${USERNAME}

RUN curl -LsSf https://raw.githubusercontent.com/cisco-ai-defense/defenseclaw/main/scripts/install.sh \
    | VERSION="${DEFENSECLAW_VERSION}" bash -s -- --yes \
  && uv pip install --python "${DEFENSECLAW_HOME}/.venv/bin/python" \
       cisco-ai-skill-scanner \
       cisco-ai-mcp-scanner \
       cisco-aibom \
  && rm -rf "${HOME}/.cache" "${HOME}/.npm"

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/openclaw-defenseclaw-entrypoint"]
CMD ["bash", "-l"]
