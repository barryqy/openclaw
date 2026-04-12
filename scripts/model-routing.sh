#!/usr/bin/env bash

lab_llm_source_model() {
  local raw_model="${1:-${LLM_MODEL:-gpt-4o}}"
  raw_model="${raw_model#"${raw_model%%[![:space:]]*}"}"
  raw_model="${raw_model%"${raw_model##*[![:space:]]}"}"

  if [ -z "${raw_model}" ]; then
    printf '%s\n' "gpt-4o"
    return 0
  fi

  printf '%s\n' "${raw_model}"
}

lab_llm_is_openai_native_model() {
  local model_id="${1:-}"

  case "${model_id}" in
    gpt-*|chatgpt-*|codex-*|o1*|o3*|o4*|o5*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lab_llm_direct_model() {
  local raw_model
  local provider
  local model_id

  raw_model="$(lab_llm_source_model "${1:-}")"

  if [[ "${raw_model}" != */* ]]; then
    printf '%s\n' "${raw_model}"
    return 0
  fi

  provider="${raw_model%%/*}"
  model_id="${raw_model#*/}"

  case "${provider}" in
    openai|anthropic|azure|bedrock|gemini|vertex_ai|openrouter|groq|ollama|mistral|xai|deepseek|llm-image)
      printf '%s\n' "${model_id}"
      ;;
    *)
      printf '%s\n' "${raw_model}"
      ;;
  esac
}

lab_llm_litellm_model() {
  local raw_model
  local provider
  local model_id

  raw_model="$(lab_llm_source_model "${1:-}")"

  if [[ "${raw_model}" == */* ]]; then
    provider="${raw_model%%/*}"
    model_id="${raw_model#*/}"

    if [ "${provider}" = "llm-image" ]; then
      printf 'openai/%s\n' "${model_id}"
      return 0
    fi

    printf '%s\n' "${raw_model}"
    return 0
  fi

  if lab_llm_is_openai_native_model "${raw_model}"; then
    printf '%s\n' "${raw_model}"
    return 0
  fi

  printf 'openai/%s\n' "${raw_model}"
}

lab_llm_export_variants() {
  local raw_model

  raw_model="$(lab_llm_source_model "${1:-}")"

  export LAB_LLM_SOURCE_MODEL="${raw_model}"
  export LAB_LLM_DIRECT_MODEL="$(lab_llm_direct_model "${raw_model}")"
  export LAB_LLM_LITELLM_MODEL="$(lab_llm_litellm_model "${raw_model}")"
}
