# Ship Finder Architecture

This document describes the committed Ship Finder core at version 0.4.0 and
the separately versioned Alphabetical Catalogue add-on at version 0.3.4. It
also defines the boundary between published components and personal advisor
experiments.

## Design goals

- Remain savegame-safe and read-only apart from UI selection and camera motion.
- Query current game state instead of persisting ship snapshots.
- Keep Anno XML responsible for integration and Lua responsible for behavior.
- Use deterministic natural sorting and stable object IDs.
- Keep the published UI catalogue separate from the core package.
- Exclude failing player-specific experiments from published components.

## Component boundaries

### Metadata and Lua loading

`ship-finder/modinfo.json` defines the mod identity, version, savegame-safety
metadata, and Lua bootstrap:

```text
require("ship-finder") -> ShipFinder:Load()
```

The core has ModID `ship-finder-sirlocksley`, targets Anno schema version 8,
does not require a new game, and is marked safe to remove.

### XML integration adapter

`ship-finder/data/base/config/export/assets.xml` adds only two input bindings to
Anno's existing shortcut configuration:

```text
Ctrl+F       -> ShipFinder:FindNextAlphabeticalShip()
Ctrl+Shift+F -> ShipFinder:FindPreviousAlphabeticalShip()
```

The core XML deliberately contains no custom storyline, decision, or gameplay
assets. This keeps the stable package small and isolates advisor experiments.

### Lua application logic

`ship-finder/shipfinder/ship-finder.lua` owns the runtime behavior:

1. Query ship objects in the active session.
2. Keep objects that expose `Nameable`.
3. Convert each result to a small `{ id, name }` record.
4. Natural-sort the records by case-insensitive name and then object ID.
5. Resolve the next or previous position relative to the remembered object ID.
6. Select the resolved ship and move the camera to it.

The relevant Anno APIs are:

```lua
Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner)
Selection:SelectByID(ship.id)
Scripts:JumpToObject(ship.id)
```

## Runtime data flow

```text
keyboard shortcut
    -> XML input binding
    -> ShipFinder navigation function
    -> active-session ship query
    -> natural-sort projection
    -> object-ID cursor resolution
    -> selection and camera jump
```

There is no file I/O or savegame mutation in this path.

## State strategy

The core remembers one transient value:

```lua
ShipFinder.lastAlphabeticalShipId
```

It stores an object ID rather than a list index or weak game-object reference.
The complete list is rebuilt on every keypress. This matters because the fleet
can change between presses:

- A new ship may be built.
- A ship may be destroyed.
- A ship may be renamed.
- A ship may enter or leave the active province.

If the remembered object ID still exists, navigation continues relative to its
new sorted position. If it no longer exists, forward navigation starts at the
first ship and backward navigation starts at the last ship.

## Natural sorting

A plain string comparison places `Traveler 11` before `Traveler 2`. The core
creates a comparison key by lowercasing the name and padding every digit run to
20 characters:

```text
Traveler 2  -> traveler 00000000000000000002
Traveler 11 -> traveler 00000000000000000011
```

Object ID is the deterministic tie-breaker when two normalized names match.

## Current-session boundary

`Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner)` operates in the
active session. Consequently, the core is dynamic within the current province
but does not provide a global cross-province fleet query. World-map ships in
transit are a separate future feature.

## Alphabetical Catalogue add-on

The proven live catalogue is tracked at:

```text
addons/ship-finder-alphabetical-catalogue
```

It has ModID `ship-finder-alphabetical-catalogue`, depends on
`ship-finder-sirlocksley`, and registers `Ctrl+Alt+F` directly in its own XML.
Keeping it separate prevents its advisor graph from destabilizing the core
shortcut module.

Its runtime data flow is:

```text
Ctrl+Alt+F
    -> add-on XML shortcut
    -> StoryLine and DecisionRoot
    -> live letter-index decision
    -> live ship-page decision
    -> row Sequence sets group/page/slot variables
    -> ActionExecuteScript
    -> rebuild and natural-sort the same live ship list
    -> select ship and jump camera
```

The add-on owns GUIDs `2003000–2003144`, its localization LineIds, and
`data/script/shipfinder/select-dynamic-catalogue-ship.lua`. Dynamic option
labels and the click handler intentionally use identical grouping and sorting
rules so a displayed name resolves to the same ship when clicked.

The committed generator is:

```text
tools/generate-dynamic-catalogue-test.ps1 -Target Public
```

It regenerates the add-on's XML, localization, and Lua data in the tracked
`addons/` directory.

## Personal catalogue integration

Player-specific catalogues remain under the ignored `personal/` directory and
are not published. This includes the working static Sir Locksley catalogue and
its currently failing dynamic successor.

The Lua module currently retains a small, working compatibility interface for
the static Sir Locksley catalogue:

```lua
ShipFinder:OpenCatalogueForCurrentSession(...)
ShipFinder:OpenSirLocksleyCatalogue()
```

Those functions map a current session GUID to an add-on storyline GUID and ask
Anno to open it. The add-on owns its decisions, text, selection adapter, and
asset namespace.

The core compatibility helpers do not change the core shortcut XML.

## Savegame-safety model

The core performs only these externally visible actions:

- Read current ship objects and names.
- Update transient Lua cursor state.
- Select a ship in the UI.
- Move the camera.

It does not create or destroy assets, write condition variables into the
savegame, change route assignments, change cargo, or modify simulation values.

## Failure handling and logging

The Lua module returns `false` and writes a diagnostic log when no named ships
are available or when a requested optional catalogue has no entry for the
current session. Successful navigation logs position, fleet size, name, and ID.

Useful log prefix:

```text
[Ship Finder]
```

Anno logs are normally stored under:

```text
C:\Users\Enrico\OneDrive\Dokumente\Anno 117 - Pax Romana\log
```

## Validation strategy

The core has no standalone automated runtime test because Anno supplies its Lua
APIs. Validation therefore has two layers:

1. Static validation:
   - Parse `modinfo.json` as JSON.
   - Parse `assets.xml` as XML.
   - Parse the Lua module with a Lua parser.
   - Confirm shortcut identifiers and key combinations are unique across the
     core and published add-on.
2. In-game regression:
   - Restart Anno completely after deployment.
   - Verify forward, backward, and wraparound behavior.
   - Verify natural numeric ordering.
   - Verify create, destroy, rename, and province changes.
   - Open Ctrl+Alt+F, navigate letters/pages, and select exact rows.
   - Inspect the log for selection and camera-jump entries.

## Extension rules

- Do not reuse an Anno asset GUID for a different template type.
- Keep generated advisor assets outside the core package.
- Keep UI labels and click handlers on the same filtering and sorting rules.
- Re-query live objects rather than caching game-object references.
- Preserve Ctrl+F and Ctrl+Shift+F regression behavior when adding UI features.
- Commit generated assets only when they are intended to be distributed.
- Do not commit failing personal experiments with stable core changes.
