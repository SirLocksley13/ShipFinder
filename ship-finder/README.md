# Ship Finder

Savegame-safe quality-of-life navigation for ships in Anno 117: Pax Romana.

## Core shortcuts

- `Ctrl+F`: select the next ship alphabetically in the current province.
- `Ctrl+Shift+F`: select the previous ship alphabetically in the current
  province.

The list is rebuilt from live game objects for every shortcut press. Newly
built ships appear automatically, destroyed ships disappear, and renamed ships
move to their new sorted position. Names use natural sorting, so `Traveler 2`
appears before `Traveler 11`.

## Alphabetical Catalogue add-on

The repository includes a separately versioned advisor add-on at
`addons/ship-finder-alphabetical-catalogue`:

- `Ctrl+Alt+F`: a proven live alphabetical catalogue for the current province.

It depends on the core mod but owns its XML decisions, dynamic text, shortcut,
and row-selection Lua. It is kept separate so catalogue UI development cannot
destabilize the two core navigation shortcuts.

The static route-oriented Sir Locksley catalogue (`Ctrl+Alt+S`) and its failing
dynamic successor remain in the ignored `personal/` development directory and
are not published.

## Scope and limitations

- Ship Finder only reads ship objects, selects one, and moves the camera.
- It does not modify ships, cargo, routes, inventory, or savegame simulation
  data.
- Queries are scoped to the active game session/province. Ships traveling on
  the world map between provinces are not currently included.
- A complete game restart is recommended after deploying XML or Lua changes.

See [the architecture document](../docs/ARCHITECTURE.md) for component
boundaries, data flow, state handling, and extension guidance.
