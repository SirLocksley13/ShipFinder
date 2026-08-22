# Ship Finder Changelog

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
