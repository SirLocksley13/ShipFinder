# Ship Finder for Anno 117

Ship Finder is a savegame-safe quality-of-life mod for **Anno 117: Pax Romana**.
It finds ships from the current province, selects the chosen ship and moves the
camera directly to it.

## Core shortcuts

- `Ctrl+F`: Next ship
- `Ctrl+Shift+F`: Previous ship

The core uses live current-province queries and natural sorting, so newly built,
renamed and destroyed ships are reflected immediately, and names such as
`Traveler 2` sort before `Traveler 11`.

## Unified menu

The published add-on is located at:

`addons/ship-finder-unified-menu`

Press `Ctrl+Alt+F` to open a live menu containing only ships in the current
province.

General users receive:

- Alphabetical Ship List
- Active Trade Routes
- Trade Ships Needing Attention
- Warships
- Other Ships

## Optional personal naming system

The naming format is **not an official Anno 117 convention**. It is a personal
fleet-naming system created by Dr. Enrico Handrick.

Trade-route ships use:

```text
L_<first 3 letters of island 1>_<first 3 letters of island 2>_<number>
A_<first 3 letters of island 1>_<first 3 letters of island 2>_<number>
```

Examples:

```text
L_ROM_OST_01
A_WUL_BRE_02
```

`L` represents Latium, `A` represents Albion, the two island fields use only
the first three letters of the islands, and the final number distinguishes
multiple ships using the same route.

Emergency transport ships that normally wait in an island harbor are named
with the word `Runner` and the island identifier, for example:

```text
Runner ROM
Runner OST
```

Players who do not use this system still receive the complete general Ship
Finder menu. When an `L_...` or `A_...` trade-route name is detected, Ship
Finder automatically enables the personal menu, including the separate Runners
category.

See [ship-finder/README.md](ship-finder/README.md) for the core behavior,
[addons/ship-finder-unified-menu/README.md](addons/ship-finder-unified-menu/README.md)
for the unified menu, and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the
technical design.

## Author

Developed by **Dr. Enrico Handrick** under the GitHub username **SirLocksley13**.
