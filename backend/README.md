# NauGi mock REST API

The mock uses **json-server 0.17.4**, listens on port **3000**, and has
`/recipes` and `/ingredients` resources. Both follow json-server's normal
GET, POST, PUT/PATCH, and DELETE contract; IDs are strings matching the app models.
The mock is for a local classroom demo and does not implement authentication.

From the repository root on Windows:

```powershell
.\scripts\api.ps1 -Action start
.\scripts\api.ps1 -Action logs
.\scripts\api.ps1 -Action stop
```

`start` uses Docker when its daemon is available, otherwise Node.js 20+ in the
foreground. Use `-Mode node` to force Node or `-Mode docker` to require Docker.
Stop a foreground Node API with Ctrl+C. Its logs appear in the same terminal.

Without the helper, from `backend/`:

```text
npm ci
npm start
npm test
```

Docker alternative: `docker compose up -d --build api` from repository root.
`API_PORT` can change the host port for Compose; Node accepts `PORT`.

## Seed and runtime data

- `app/lib/data/catalog.dart` is the source of the 20 sample recipes and 25
  ingredients.
- From `app/`, `dart run tool/export_seed.dart` exports `backend/seed.json` and
  the assignment's tracked `backend/db.json` example. `--check` checks seed
  consistency without modifying files.
- The server writes only **`backend/runtime/db.json`**, which Git ignores.
  It copies `seed.json` there only if the runtime file is absent. Restarting,
  rebuilding the container, and regenerating the seed preserve saved edits.
- Docker mounts the runtime directory so changes survive container replacement.

To intentionally discard all runtime edits:

```powershell
.\scripts\api.ps1 -Action reset
.\scripts\api.ps1 -Action start
```

The helper stops the Docker API before resetting and refuses if a foreground
process still listens on the API port. With Node only, stop the API first and run
`npm run reset` in `backend/`, then `npm start`.

`npm test` starts a real HTTP server on a random local port with a temporary
database. It checks recipe/ingredient seed references, non-destructive startup,
and GET/POST/PUT/DELETE including the persisted update. It does not touch runtime
data. Device addresses and build settings are documented in
[`app/config/README.md`](../app/config/README.md).
