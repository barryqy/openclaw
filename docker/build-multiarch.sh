#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${1:-ghcr.io/example/openclaw-defenseclaw}"
IMAGE_TAG="${2:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-2026.3.24}"
DEFENSECLAW_VERSION="${DEFENSECLAW_VERSION:-0.2.0}"

shift $(( $# > 0 ? 1 : 0 ))
shift $(( $# > 0 ? 1 : 0 ))

extra_args=("$@")

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to build the container image." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx is required for the multi-arch build." >&2
  exit 1
fi

output_args=(--push)
if [ "${PUSH:-1}" = "0" ]; then
  if [ "${PLATFORMS}" != "linux/amd64" ] && [ "${PLATFORMS}" != "linux/arm64" ]; then
    echo "Local loads only support a single platform. Set PLATFORMS=linux/amd64 or linux/arm64 when PUSH=0." >&2
    exit 1
  fi
  output_args=(--load)
fi

docker buildx build \
  --platform "${PLATFORMS}" \
  --build-arg "OPENCLAW_VERSION=${OPENCLAW_VERSION}" \
  --build-arg "DEFENSECLAW_VERSION=${DEFENSECLAW_VERSION}" \
  -f "${ROOT_DIR}/docker/Dockerfile" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  "${output_args[@]}" \
  "${extra_args[@]}" \
  "${ROOT_DIR}"
