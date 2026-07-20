# Ship Finder - Alphabetical Catalogue

Live alphabetical catalogue for the current player's ships in the current province.

- Requires the Ship Finder core mod (`ship-finder-sirlocksley`).
- Shortcut: `Ctrl+Alt+F`.
- Ship names and letter counts are resolved when the catalogue opens.
- Names use natural alphabetical sorting (`Ship 2` before `Ship 11`).
- Four names are shown per result page, leaving room for navigation.
- No player-specific fleet generation is required.

The add-on is savegame-safe and read-only apart from selecting a ship and
moving the camera. It does not change ships, cargo, routes, or simulation data.

Generate its XML/text/Lua data with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\tools\generate-dynamic-catalogue-test.ps1 -Target Public
```

See [the project architecture](../../docs/ARCHITECTURE.md) for the decision
graph and click-handler data flow.
