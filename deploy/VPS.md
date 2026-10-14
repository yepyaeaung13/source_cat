# One VPS + Caddy + SQLite

Build on a machine matching the VPS's OS and architecture, with Elixir 1.20/OTP 29,
Node/npm, Python 3, and native build tools installed. Alternatively build the
provided Docker image and run it behind Caddy with a persistent `/data` volume.

```sh
mix deps.get --only prod
npm ci --prefix assets
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
```

The same build is available as `./deploy/build-release.sh`.

Copy `_build/prod/rel/source_cat/` to `/opt/sourcecat/` on the VPS. Create a service
user `sourcecat` and a persistent, writable `/var/lib/sourcecat/` directory. Install
Caddy from its official package source and point your domain's DNS at the VPS.
Only expose ports 80/443 (and your SSH port); keep Phoenix port 4000 private.

Create `/etc/sourcecat.env` with root ownership and permissions `0600`:

```dotenv
PHX_SERVER=true
PHX_HOST=YOUR_DOMAIN
PORT=4000
POOL_SIZE=1
DATABASE_PATH=/var/lib/sourcecat/sourcecat.sqlite
SECRET_KEY_BASE=YOUR_STABLE_RANDOM_SECRET
ADMIN_PASSWORD=YOUR_STUDIO_PASSWORD
```

Generate the signing secret with `mix phx.gen.secret`. Use a Studio password of
at least 12 characters; do not commit secrets. Install
[sourcecat.service](sourcecat.service) as `/etc/systemd/system/sourcecat.service`.
The release automatically migrates its own database at startup. The service
places generated release configuration in its writable state directory.

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now sourcecat
sudo systemctl status sourcecat
curl -f http://localhost:4000/healthz
```

Use this Caddyfile with your real domain:

```caddy
YOUR_DOMAIN {
  encode zstd gzip
  reverse_proxy 127.0.0.1:4000
}
```

Validate and reload Caddy, then open the HTTPS domain and `/admin`.
Production cookies require HTTPS. Caddy supplies the forwarded protocol used by
Phoenix's HTTPS enforcement. Keep one app process for this SQLite database.

For updates, stage the new release separately, back up the database, stop the
service, replace the release, and restart. Keep the previous release and database
backup together: schema changes can prevent an old release from reading a newer
schema. A single VPS deployment has downtime during updates.

Use SQLite's online backup API rather than copying an active database with WAL:

```sh
sudo -u sourcecat sqlite3 /var/lib/sourcecat/sourcecat.sqlite ".backup '/var/lib/sourcecat/sourcecat-backup.sqlite'"
```

The provided [backup script](backup.sh) writes timestamped backups to
`/var/backups/sourcecat` when run as root. The [Caddyfile](Caddyfile) is also
provided as a starting point.

Copy backups off the VPS and schedule them using your host's backup tooling.
To restore, stop SourceCat, restore the database and correct its ownership, remove
stale WAL/SHM files, and restart. Import the Gleam data locally first and transfer
an **Ash database backup**; never point the release at the Gleam database.
