# Ship Finder Changelog

## v1.5.1 — Controls Baseline

### Changed
- The Ship Finder opener is now a native configurable Anno control.
- Default remains **Ctrl+Alt+F**.
- Permanent shortcut identifier: `SirLocksleyShipFinderOpen`.
- Permanent command: `ShipFinderCombinedRoot.Open(ShipFinderCombinedRoot)`.
- The old proof-era non-configurable Ctrl+Alt+F binding was removed.

### Deliberately unchanged
- No Ship Finder Lua logic changed.
- No Governor-menu behavior changed.
- No emergency-exit behavior added yet.
- No save/load lifecycle behavior changed.
- Ctrl+Alt+1-9 direct ship jumps and Ctrl+Alt+0 return/back remain unchanged.
- Scanning, parchments, menus, localization and read-only gameplay behavior remain the v1.5.0 baseline.

## v1.5.0

### New
- Complete French localization for menus and Lua-generated parchments.
- Detailed Patch 2.0 Attention presentation:
  - All Ships Paused
  - Wait for Goods with the affected island

### Improved
- Ctrl+Alt+F now opens the Ship Finder main menu immediately.
- Ships Needing Attention scans native Trade Route details only on demand.
- Ships by Island retains its independent on-demand scan/cache behavior.
- Fleet Summary retains its dedicated robust post-yield handoff.
- Attention retains the proven freeze-safe post-yield handoff.

### Cleanup
- Removed obsolete development shortcut Ctrl+Alt+P.
- Removed its unused standalone Attention entry function.
- Kept the underlying Attention parchment renderer because the production
  Ships Needing Attention feature uses it.
- Removed internal French-review documentation from the public package.

### Preserved
- Ctrl+Alt+1-9 direct ship jumps
- Ctrl+Alt+0 return/back behavior
- Active Trade Routes
- Independent Ships
- Warships
- All Ships A-Z
- Ships by Island
- Fleet Overview
- English and German localization
- Read-only behavior
