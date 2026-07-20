# Ship Finder for Anno 117

Ship Finder is a savegame-safe quality-of-life mod that selects ships in
natural alphabetical order and moves the camera to the selected ship.

The committed core provides:

- `Ctrl+F` for the next ship.
- `Ctrl+Shift+F` for the previous ship.
- Live current-province queries, including newly built, renamed, and destroyed
  ships.
- Natural sorting, so `Traveler 2` appears before `Traveler 11`.

The repository also includes the proven **Alphabetical Catalogue** add-on under
`addons/ship-finder-alphabetical-catalogue`. It uses `Ctrl+Alt+F` to open a
live advisor menu containing the current province's ships.

Player-specific advisor experiments remain under the ignored `personal/`
development directory and are not published.

See [ship-finder/README.md](ship-finder/README.md) for user-facing behavior and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the technical design.

Creator: SirLocksley
