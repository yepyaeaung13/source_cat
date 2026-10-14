# SourceCat

A programming blog and community for Myanmar developers. The Gleam app's
features are ported to **React + TypeScript**, **Phoenix + Ash**, and **SQLite**.

- Dark YouTube-style feed, topic/search/type filters, Crash Course, article pages,
  click-to-play YouTube embeds, white cat branding, and the animated sleepy cat.
- Creator Studio: password sign-in, article/video CRUD, sanitized rich text,
  preview, drafts, immutable slugs, filters, pagination, and deletion confirmation.
- Visitor accounts: short generated names, PIN-only sign-in, automatic dialog
  closing after authentication, PIN changes, and private bookmarks.
- Public community questions and threaded conversations on questions and posts.
  Author badges, root pagination, ownership checks, and comment tombstones keep
  replies readable. Guests can browse all published activity.
- Ash policies enforce permissions, server-side validation protects writes,
  CSRF protects sessions, persistent limits slow login guessing and posting spam.
  PIN hashes use PBKDF2-SHA256; sessions expire and can be revoked.

## Run locally

```sh
cp .env.example .env
# Choose ADMIN_PASSWORD in .env (at least 12 characters for production).
mix setup
mix phx.server
```

Open [localhost:4000](http://localhost:4000) or
[Creator Studio](http://localhost:4000/admin). The local `.env` is ignored by Git.
Visitor PINs contain 6–12 digits. There is no visitor password or email requirement;
keep your generated username and PIN because there is no email recovery flow.

## Import the Gleam app

Back up the target database before importing. The source is opened read-only;
existing target identities are retained. IDs, dates, PIN hashes, questions,
comments, soft deletions, and bookmarks carry over. Legacy sessions do not.

```sh
mix source_cat.import_gleam --database /absolute/path/to/gleam-database.sqlite
```

The databases have different schemas. Do not use the original Gleam database as
Phoenix's database. The import tool requires Python 3 and rejects non-PIN accounts.

## Code and checks

React pages and components live in `assets/js/`; shared CSS is in
`assets/css/app.css`. Ash domains/resources live in `lib/source_cat/` and JSON
controllers in `lib/source_cat_web/controllers/`. Public posts use the generated
Ash TypeScript RPC client. Other account/conversation endpoints use the same
Phoenix session and CSRF checks. Generated files should not be edited manually.

```sh
mix ash_typescript.codegen
npm run --prefix assets typecheck
mix precommit
```

The tests cover permissions, drafts, sanitization, PINs, rate limits, replies,
bookmarks, session revocation, conversation pagination, and repeatable data import.

## Deploy

Use one persistent SQLite writer. Production requires `ADMIN_PASSWORD`,
`SECRET_KEY_BASE`, `DATABASE_PATH`, `PHX_HOST`, and `PHX_SERVER=true`.
React assets are served by Phoenix; no separate Node service is required.
Migrations run automatically when an Elixir release starts. After building a
native release, run `python3 scripts/smoke_release.py` to verify it against an
isolated temporary database, including a restart and persistence check.

- [Fly.io deployment](deploy/FLY.md): Docker release, one Machine, SQLite volume.
- [One VPS with Caddy](deploy/VPS.md): native release, systemd, HTTPS, backups.

Do not rotate SECRET_KEY_BASE during routine updates. Keep online SQLite backups
outside the host/volume, and stop the writer before a restore. The bundled Ash
Authentication/Admin dependencies are available, but this app deliberately uses
its existing PIN account flow and custom React Creator Studio.
