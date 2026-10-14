#!/usr/bin/env bash
set -euo pipefail
# Run as root. Uses SQLite's online backup API for a consistent WAL snapshot.
backup_dir=/var/backups/sourcecat
install -d -m 0700 "$backup_dir"
backup_file="$backup_dir/sourcecat-$(date -u +%Y%m%dT%H%M%S).sqlite"
umask 077
sqlite3 /var/lib/sourcecat/sourcecat.sqlite ".backup '$backup_file'"
printf 'Backup saved: %s\n' "$backup_file"
