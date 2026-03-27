#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

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

go_runtime_ok() {
  if ! command -v go >/dev/null 2>&1; then
    return 1
  fi

  local go_ver
  local major
  local minor

  go_ver="$(go version 2>/dev/null | awk '{print $3}')"
  go_ver="${go_ver#go}"

  if [ -z "${go_ver}" ]; then
    return 1
  fi

  IFS=. read -r major minor _ <<<"${go_ver}"

  if [ "${major}" -gt 1 ]; then
    return 0
  fi

  [ "${minor}" -ge 25 ]
}

install_go_runtime() {
  local os_name
  local arch
  local go_os
  local go_arch
  local go_ver="1.25.0"
  local archive_name
  local install_root
  local go_bin_dir
  local tmpdir

  os_name="$(uname -s)"
  arch="$(uname -m)"

  case "${os_name}" in
    Linux) go_os="linux" ;;
    Darwin) go_os="darwin" ;;
    *)
      echo "Unsupported operating system for Go bootstrap: ${os_name}" >&2
      return 1
      ;;
  esac

  case "${arch}" in
    x86_64|amd64) go_arch="amd64" ;;
    aarch64|arm64) go_arch="arm64" ;;
    *)
      echo "Unsupported CPU architecture for Go bootstrap: ${arch}" >&2
      return 1
      ;;
  esac

  archive_name="go${go_ver}.${go_os}-${go_arch}.tar.gz"
  install_root="${HOME}/.local/share/defenseclaw-go/go${go_ver}-${go_os}-${go_arch}"
  go_bin_dir="${install_root}/bin"

  if [ ! -x "${go_bin_dir}/go" ]; then
    echo "Installing Go ${go_ver} for DefenseClaw..."
    tmpdir="$(mktemp -d)"
    download_file "https://go.dev/dl/${archive_name}" "${tmpdir}/${archive_name}"
    mkdir -p "${HOME}/.local/share/defenseclaw-go" "${HOME}/.local/bin"
    tar -xzf "${tmpdir}/${archive_name}" -C "${tmpdir}"
    rm -rf "${install_root}"
    mv "${tmpdir}/go" "${install_root}"
    rm -rf "${tmpdir}"
  fi

  mkdir -p "${HOME}/.local/bin"
  ln -sf "${go_bin_dir}/go" "${HOME}/.local/bin/go"
  ln -sf "${go_bin_dir}/gofmt" "${HOME}/.local/bin/gofmt"
  export PATH="${go_bin_dir}:${HOME}/.local/bin:${PATH}"
  hash -r

  if [ ! -x "${go_bin_dir}/go" ]; then
    echo "Go bootstrap completed, but the go binary is missing at ${go_bin_dir}/go." >&2
    return 1
  fi

  echo "Go ready: $("${go_bin_dir}/go" version)"
}

ensure_go_runtime() {
  if go_runtime_ok; then
    return 0
  fi

  install_go_runtime
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

defenseclaw_parent_dir="$(dirname "${DEFENSECLAW_DIR}")"
mkdir -p "${defenseclaw_parent_dir}"
cd "${defenseclaw_parent_dir}"

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "Cloning DefenseClaw from ${DEFENSECLAW_TEMP_REPO}..."
  git clone "${DEFENSECLAW_TEMP_REPO}" "${DEFENSECLAW_DIR}"
fi

cd "${DEFENSECLAW_DIR}"

ensure_go_runtime
ensure_uv_runtime

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to build the DefenseClaw plugin." >&2
  echo "Run the OpenClaw install step first so Node.js is bootstrapped into the lab pod." >&2
  exit 1
fi

UV_PYTHON_BIN="$(resolve_defenseclaw_python)"

if [ -x ".venv/bin/python" ] && ! python_version_ok ".venv/bin/python" 3 11; then
  rm -rf .venv
fi

uv venv .venv --python "${UV_PYTHON_BIN}"
uv pip install -e . --python .venv/bin/python
make gateway-install plugin-install
hash -r

if ! command -v defenseclaw-gateway >/dev/null 2>&1; then
  echo
  echo "DefenseClaw gateway is still not on PATH after the first install pass." >&2
  echo "Recovery: run 'make gateway-install' from ${DEFENSECLAW_DIR} and then rerun this helper." >&2
  exit 1
fi

# shellcheck disable=SC1091
source .venv/bin/activate
./scripts/setup-scanners.sh
defenseclaw init --skip-install
defenseclaw policy activate strict
defenseclaw status
