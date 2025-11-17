#!/bin/sh
set -e

API_KEY="${API_KEY:-public_token}"
sed -i "s|\${API_KEY}|${API_KEY}|g" configs/config-stt-en_fr-hf.toml

exec moshi-server worker --config configs/config-stt-en_fr-hf.toml --port ${SERVER_PORT:-8000}