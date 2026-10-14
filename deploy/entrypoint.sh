#!/bin/sh
set -eu
umask 077
: "${SECRET_KEY_BASE:?Set SECRET_KEY_BASE}"
: "${ADMIN_PASSWORD:?Set ADMIN_PASSWORD}"
if [ "${#SECRET_KEY_BASE}" -lt 64 ] || [ "${#ADMIN_PASSWORD}" -lt 12 ]; then
  echo 'SECRET_KEY_BASE must have 64+ characters and ADMIN_PASSWORD 12+ characters.' >&2
  exit 64
fi
: "${DATABASE_PATH:=/data/sourcecat.sqlite}"
case "$DATABASE_PATH" in /data/*) ;; *) echo 'DATABASE_PATH must be under /data.' >&2; exit 64 ;; esac
if [ -n "${FLY_APP_NAME:-}" ]; then
  if ! awk '$2 == "/data" { found=1 } END { exit !found }' /proc/mounts; then
    echo 'Mount the sourcecat_data volume at /data.' >&2
    exit 64
  fi
  : "${PHX_HOST:=${FLY_APP_NAME}.fly.dev}"
else
  : "${PHX_HOST:?Set PHX_HOST for your site}"
fi
export DATABASE_PATH PHX_HOST
mkdir -p "$(dirname "$DATABASE_PATH")"
sqlite3 "$DATABASE_PATH" 'PRAGMA journal_mode=WAL;' > /dev/null
chown -R webapp:webapp /data
chmod 700 /data
chmod 600 "$DATABASE_PATH"
# Ecto.Migrator runs inside the supervised application before HTTP starts.
exec su-exec webapp:webapp "$@"
