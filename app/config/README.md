# Local API configuration

Copy an example to `dev.json` (ignored by Git), then pass
`--dart-define-from-file=config/dev.json`, or use `tool/naugi.ps1 -ConfigPath config/dev.json`.

- Android emulator: `dev.example.json` uses `http://10.0.2.2:3000`.
- iOS simulator / local desktop: `ios.example.json` uses `http://localhost:3000`.
- Physical device: copy `device.example.json` and replace the example address with
  your computer's current LAN IPv4 address. Connect both devices to the same network
  and allow inbound TCP port 3000 through the computer's firewall.

`API_BASE_URL` is a build setting. Restart/rebuild after changing it. The Android
demo flavor and debug builds allow HTTP to the local mock; regular release builds
require HTTPS. Do not add credentials to these files.
