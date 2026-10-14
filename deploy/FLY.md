# SourceCat Phoenix on Fly.io

This app uses one Machine in Singapore, a persistent 1 GB SQLite volume, and
Fly HTTPS. The Dockerfile builds the React assets and an Elixir release. Runtime
runs as an unprivileged user. Migrations run at app startup on the mounted volume;
a temporary Fly release Machine cannot access this volume.

Install [flyctl](https://docs.fly.io/flyctl/install/) and sign in. From this project:

```sh
fly auth login
fly launch --copy-config --no-deploy --no-db --ha=false --name YOUR_UNIQUE_APP_NAME --region sin
fly volumes list
```

If no volume exists, create it:

```sh
fly volumes create sourcecat_data --region sin --size 1 --snapshot-retention 14
```

Generate a stable cookie signing secret and choose the Studio password:

```sh
python3 - <<'PY' | fly secrets import --stage
import getpass, secrets, sys
password = getpass.getpass('Studio password (12+ characters): ')
if len(password) < 12 or any(c in password for c in ['\n', '\r', '"']):
    sys.exit('Use 12+ characters without newlines or double quotes.')
print('SECRET_KEY_BASE=' + secrets.token_hex(64))
print('ADMIN_PASSWORD="' + password + '"')
PY
fly config validate
fly deploy --ha=false
fly checks list
fly open
```

`PHX_HOST` defaults to your Fly app hostname. Set it explicitly for a custom
domain after configuring Fly DNS and certificates. `SECRET_KEY_BASE` and
`ADMIN_PASSWORD` are mandatory. Never enable development routes in production.

Deploy updates with `fly deploy --ha=false`. Keep one Machine and one region:
plain SQLite volumes do not replicate. Updates or host failure can cause downtime.
Daily volume snapshots retain 14 days; maintain separate off-platform backups.

```sh
fly ssh console -C "sqlite3 /data/sourcecat.sqlite \".backup '/data/sourcecat-backup.sqlite'\""
fly ssh sftp get /data/sourcecat-backup.sqlite ./sourcecat-backup.sqlite
```

To restore, stop the database writer, restore a backup to the mounted volume,
and restart. Never overwrite a live database. Secrets, local databases and build
caches are excluded from the Docker context.

For local Docker verification, use an ignored `.env.container` containing the
secrets and `PHX_HOST=localhost`. Production forces HTTPS; put it behind a local
HTTPS proxy to test browser login, or verify health using the host excluded from
SSL redirection:

```sh
docker build -t sourcecat:local .
docker volume create sourcecat-local-data
docker run --rm -p 127.0.0.1:4000:4000 --env-file .env.container -v sourcecat-local-data:/data sourcecat:local
```

Existing Gleam data must first be imported with `mix source_cat.import_gleam` on
your local machine. Back up the resulting **Ash** database and transfer that
backup to `/data/sourcecat.sqlite` during a maintenance stop. The schemas differ;
do not point Phoenix directly at the original Gleam database.
