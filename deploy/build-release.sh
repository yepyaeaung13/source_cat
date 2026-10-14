#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export MIX_ENV=prod
mix deps.get --only prod
npm ci --prefix assets
mix compile
mix assets.deploy
mix release --overwrite
printf 'Release ready: %s\n' "$PWD/_build/prod/rel/source_cat"
