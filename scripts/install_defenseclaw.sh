#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

DC_VENV_DIR="${DEFENSECLAW_DIR}/.venv"
DC_PYTHON="${DC_VENV_DIR}/bin/python"
DC_CLI="${DC_VENV_DIR}/bin/defenseclaw"

download_file() {
  local url="$1"
  local out_file="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${out_file}"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "${out_file}" "${url}"
    return 0
  fi

  python3 - "${url}" "${out_file}" <<'PY'
import sys
import urllib.request

urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
PY
}

python_version_ok() {
  local python_bin="$1"
  local min_major="${2:-3}"
  local min_minor="${3:-10}"

  "${python_bin}" "${min_major}" "${min_minor}" - <<'PY' >/dev/null 2>&1
import sys

min_major = int(sys.argv[1])
min_minor = int(sys.argv[2])

raise SystemExit(0 if sys.version_info >= (min_major, min_minor) else 1)
PY
}

ensure_uv_runtime() {
  local tmpdir

  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  echo "Installing uv for DefenseClaw..."
  tmpdir="$(mktemp -d)"
  download_file "https://astral.sh/uv/install.sh" "${tmpdir}/install-uv.sh"
  mkdir -p "${HOME}/.local/bin"
  UV_UNMANAGED_INSTALL="${HOME}/.local/bin" sh "${tmpdir}/install-uv.sh" --quiet
  rm -rf "${tmpdir}"

  export PATH="${HOME}/.local/bin:${PATH}"
  hash -r

  if ! command -v uv >/dev/null 2>&1; then
    echo "uv was installed, but it is still not on PATH." >&2
    return 1
  fi

  echo "uv ready: $(uv --version)"
}

resolve_defenseclaw_python() {
  local candidate
  local uv_python

  for candidate in python3.13 python3.12 python3.11 python3; do
    if ! command -v "${candidate}" >/dev/null 2>&1; then
      continue
    fi

    if python_version_ok "${candidate}" 3 11; then
      command -v "${candidate}"
      return 0
    fi
  done

  uv_python="$(uv python find 3.12 2>/dev/null || true)"
  if [ -n "${uv_python}" ] && [ -x "${uv_python}" ]; then
    echo "${uv_python}"
    return 0
  fi

  echo "Installing Python 3.12 for DefenseClaw..." >&2
  uv python install 3.12
  uv_python="$(uv python find 3.12 2>/dev/null || true)"

  if [ -n "${uv_python}" ] && [ -x "${uv_python}" ]; then
    echo "${uv_python}"
    return 0
  fi

  echo "DefenseClaw needs Python 3.11 or newer so the MCP scanner can install." >&2
  return 1
}

sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${path}" | awk '{print $1}'
    return 0
  fi

  shasum -a 256 "${path}" | awk '{print $1}'
}

verify_checksum() {
  local file_path="$1"
  local file_name="$2"
  local checksums_file="$3"
  local expected
  local actual

  expected="$(awk -v f="${file_name}" '$2 == f {print $1; exit}' "${checksums_file}")"
  if [ -z "${expected}" ]; then
    echo "No checksum entry found for ${file_name}; keeping the downloaded release asset." >&2
    return 0
  fi

  actual="$(sha256_file "${file_path}")"
  if [ "${expected}" != "${actual}" ]; then
    echo "Checksum mismatch for ${file_name}." >&2
    echo "Expected: ${expected}" >&2
    echo "Actual:   ${actual}" >&2
    return 1
  fi
}

detect_release_platform() {
  local os_name
  local arch_name
  local os_part
  local arch_part

  os_name="$(uname -s)"
  arch_name="$(uname -m)"

  case "${os_name}" in
    Linux) os_part="linux" ;;
    Darwin) os_part="darwin" ;;
    *)
      echo "Unsupported DefenseClaw release platform: ${os_name}" >&2
      return 1
      ;;
  esac

  case "${arch_name}" in
    x86_64|amd64) arch_part="amd64" ;;
    aarch64|arm64) arch_part="arm64" ;;
    *)
      echo "Unsupported DefenseClaw release architecture: ${arch_name}" >&2
      return 1
      ;;
  esac

  printf '%s_%s\n' "${os_part}" "${arch_part}"
}

python_module_available() {
  local python_bin="$1"
  local module_name="$2"

  "${python_bin}" - "${module_name}" <<'PY' >/dev/null 2>&1
import importlib.util
import sys

raise SystemExit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
}

ensure_lab_scanners() {
  local missing=()

  if ! python_module_available "${DC_PYTHON}" "skill_scanner"; then
    missing+=("cisco-ai-skill-scanner")
  fi

  if ! python_module_available "${DC_PYTHON}" "mcpscanner"; then
    missing+=("cisco-ai-mcp-scanner>=4.3")
  fi

  if [ "${#missing[@]}" -eq 0 ]; then
    echo "DefenseClaw scanner dependencies are ready."
    echo "Skipping cisco-aibom because this lab does not use AI BOM commands."
    return 0
  fi

  echo "Installing missing DefenseClaw scanner dependencies: ${missing[*]}"
  uv pip install --python "${DC_PYTHON}" "${missing[@]}"
  echo "Skipping cisco-aibom because this lab does not use AI BOM commands."
}

stop_running_defenseclaw_gateway() {
  if ! command -v defenseclaw-gateway >/dev/null 2>&1; then
    return 0
  fi

  defenseclaw-gateway stop >/dev/null 2>&1 || true
  pkill -f '/defenseclaw-gateway' >/dev/null 2>&1 || true
  sleep 1
}

defenseclaw_venv_is_broken() {
  if [ ! -d "${DC_VENV_DIR}" ]; then
    return 1
  fi

  if [ ! -x "${DC_PYTHON}" ]; then
    return 0
  fi

  if ! "${DC_PYTHON}" -V >/dev/null 2>&1; then
    return 0
  fi

  if [ ! -x "${DC_VENV_DIR}/bin/python3" ]; then
    return 0
  fi

  if ! "${DC_VENV_DIR}/bin/python3" -V >/dev/null 2>&1; then
    return 0
  fi

  if [ ! -f "${DC_VENV_DIR}/pyvenv.cfg" ]; then
    return 0
  fi

  return 1
}

sync_openclaw_plugin_install() {
  local staged_plugin_dir="${DEFENSECLAW_INSTALLED_PLUGIN_DIR}"
  local target_plugin_dir="${OPENCLAW_DEFENSECLAW_PLUGIN_DIR}"

  if [ ! -f "${staged_plugin_dir}/dist/index.js" ]; then
    echo "DefenseClaw plugin artifact is missing ${staged_plugin_dir}/dist/index.js." >&2
    return 1
  fi

  rm -rf "${target_plugin_dir}"
  mkdir -p "${target_plugin_dir}"

  cp "${staged_plugin_dir}/package.json" "${target_plugin_dir}/"
  if [ -f "${staged_plugin_dir}/openclaw.plugin.json" ]; then
    cp "${staged_plugin_dir}/openclaw.plugin.json" "${target_plugin_dir}/"
  fi
  cp -r "${staged_plugin_dir}/dist" "${target_plugin_dir}/"

  if [ -d "${staged_plugin_dir}/node_modules" ]; then
    cp -r "${staged_plugin_dir}/node_modules" "${target_plugin_dir}/"
  fi

  echo "OpenClaw plugin synced: ${target_plugin_dir}"
}

download_release_artifacts() {
  local target_dir="$1"
  local platform="$2"
  local gateway_name="defenseclaw_${DEFENSECLAW_VERSION}_${platform}.tar.gz"
  local wheel_name="defenseclaw-${DEFENSECLAW_VERSION}-py3-none-any.whl"
  local plugin_name="defenseclaw-plugin-${DEFENSECLAW_VERSION}.tar.gz"

  download_file "${DEFENSECLAW_RELEASE_BASE_URL}/checksums.txt" "${target_dir}/checksums.txt"
  download_file "${DEFENSECLAW_RELEASE_BASE_URL}/${gateway_name}" "${target_dir}/${gateway_name}"
  download_file "${DEFENSECLAW_RELEASE_BASE_URL}/${wheel_name}" "${target_dir}/${wheel_name}"
  download_file "${DEFENSECLAW_RELEASE_BASE_URL}/${plugin_name}" "${target_dir}/${plugin_name}"

  verify_checksum "${target_dir}/${gateway_name}" "${gateway_name}" "${target_dir}/checksums.txt"
  verify_checksum "${target_dir}/${wheel_name}" "${wheel_name}" "${target_dir}/checksums.txt"
  verify_checksum "${target_dir}/${plugin_name}" "${plugin_name}" "${target_dir}/checksums.txt"
}

install_gateway_from_artifact() {
  local target_dir="$1"
  local platform="$2"
  local gateway_name="defenseclaw_${DEFENSECLAW_VERSION}_${platform}.tar.gz"
  local unpack_dir="${target_dir}/gateway"

  mkdir -p "${unpack_dir}" "${HOME}/.local/bin"
  tar -xzf "${target_dir}/${gateway_name}" -C "${unpack_dir}"
  install -m 0755 "${unpack_dir}/defenseclaw" "${HOME}/.local/bin/defenseclaw-gateway"
  hash -r
  echo "DefenseClaw gateway installed: ${HOME}/.local/bin/defenseclaw-gateway"
}

install_cli_from_wheel() {
  local target_dir="$1"
  local python_bin="$2"
  local wheel_name="defenseclaw-${DEFENSECLAW_VERSION}-py3-none-any.whl"

  mkdir -p "${DEFENSECLAW_DIR}"

  if defenseclaw_venv_is_broken; then
    echo "Detected a broken DefenseClaw virtual environment. Rebuilding .venv..."
    rm -rf "${DC_VENV_DIR}"
  fi

  if [ -x "${DC_PYTHON}" ] && ! python_version_ok "${DC_PYTHON}" 3 11; then
    echo "Detected an older DefenseClaw virtual environment. Rebuilding .venv..."
    rm -rf "${DC_VENV_DIR}"
  fi

  uv venv "${DC_VENV_DIR}" --python "${python_bin}"
  uv pip install --reinstall --python "${DC_PYTHON}" "${target_dir}/${wheel_name}"
  echo "DefenseClaw CLI installed: ${DC_CLI}"
}

install_plugin_from_artifact() {
  local target_dir="$1"
  local plugin_name="defenseclaw-plugin-${DEFENSECLAW_VERSION}.tar.gz"

  rm -rf "${DEFENSECLAW_INSTALLED_PLUGIN_DIR}"
  mkdir -p "${DEFENSECLAW_INSTALLED_PLUGIN_DIR}"
  tar -xzf "${target_dir}/${plugin_name}" -C "${DEFENSECLAW_INSTALLED_PLUGIN_DIR}"
  sync_openclaw_plugin_install
}

init_defenseclaw() {
  # shellcheck disable=SC1091
  source "${DC_VENV_DIR}/bin/activate"

  ensure_lab_scanners
  defenseclaw init \
    --skip-install \
    --non-interactive \
    --yes \
    --connector openclaw \
    --profile action \
    --scanner-mode local \
    --no-start-gateway \
    --no-verify
  defenseclaw policy activate strict

  # Install prepares DefenseClaw, but Module 6 should not read as
  # "configured" until configure_defenseclaw.sh finishes the handoff.
  rm -f "${DEFENSECLAW_CONFIGURED_MARKER_FILE}"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

platform="$(detect_release_platform)"

echo "[1/5] Downloading DefenseClaw ${DEFENSECLAW_VERSION} release artifacts..."
download_release_artifacts "${tmpdir}" "${platform}"
echo "DefenseClaw release: ${DEFENSECLAW_VERSION}"
echo "Artifact platform: ${platform}"

echo "[2/5] Preparing the Python environment..."
ensure_uv_runtime
UV_PYTHON_BIN="$(resolve_defenseclaw_python)"
install_cli_from_wheel "${tmpdir}" "${UV_PYTHON_BIN}"

echo "[3/5] Installing the gateway binary..."
stop_running_defenseclaw_gateway
install_gateway_from_artifact "${tmpdir}" "${platform}"

echo "[4/5] Installing the OpenClaw plugin artifact..."
install_plugin_from_artifact "${tmpdir}"

echo "[5/5] Initializing DefenseClaw for the lab..."
init_defenseclaw

defenseclaw status
