#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example"
else
  echo ".env already exists — skipped"
fi

echo "NauGi Flutter is already in app/. See GETTING_STARTED.md to start the API and run the app."
