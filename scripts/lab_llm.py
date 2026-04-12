"""Small helpers for mapping one lab model setting into runtime-specific variants."""

from __future__ import annotations


KNOWN_PROVIDER_PREFIXES = {
    "openai",
    "anthropic",
    "azure",
    "bedrock",
    "gemini",
    "vertex_ai",
    "openrouter",
    "groq",
    "ollama",
    "mistral",
    "xai",
    "deepseek",
    "llm-image",
}


def source_model_name(raw_model: str | None = None, default: str = "gpt-4o") -> str:
    model_name = (raw_model or "").strip()
    return model_name or default


def direct_model_name(raw_model: str | None = None, default: str = "gpt-4o") -> str:
    model_name = source_model_name(raw_model, default=default)
    if "/" not in model_name:
        return model_name

    provider, model_id = model_name.split("/", 1)
    provider = provider.strip()
    model_id = model_id.strip()

    if provider in KNOWN_PROVIDER_PREFIXES and model_id:
        return model_id

    return model_name
