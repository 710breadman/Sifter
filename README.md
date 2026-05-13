# Sifter

Sifter is a Windows desktop app for scanning ES-DE / EmulationStation-style ROM libraries, matching gamelist metadata and bundled Metacritic scores, selecting games by quality/size/metadata, and exporting a safe copy to another drive.

It is implemented as a PowerShell + WPF app. It runs with Windows PowerShell 5.1 or PowerShell 7 and keeps the source library read-only.

## Launch

From this folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-RomCurator.ps1
```

or:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Run-RomCurator.ps1
```

To build a double-clickable Windows EXE package:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Sifter-Exe.ps1 -Clean
```

This creates `dist\Sifter\Sifter.exe` with the required scripts, bundled data, and Sifter icon assets beside it. Keep the packaged folder together; the EXE is a Windows launcher for the PowerShell/WPF app rather than a single-file rewrite.

The app relaunches itself in STA mode if needed for WPF. On startup it loads saved paths, applies the saved Light/Dark/System theme choice, and starts a background cache load if a valid library cache exists.

## Included Data

The provided Metacritic JSONL file is bundled at:

```text
data\metacritic_game_critic_scores.jsonl
```

On first launch, Sifter copies the bundled file into the existing app-data location:

```text
%APPDATA%\RomCurator\cache\metacritic_game_critic_scores.jsonl
```

The app-data folder intentionally remains `%APPDATA%\RomCurator` for now so the rebrand does not force users to remake caches or reload settings.

The importer is intentionally flexible. It reads JSONL records with fields such as `title`, `metascore`, `release_date_text`, `rating`, `rank`, `detail_url`, and tolerates nearby schema changes. The Tools / Maintenance tab shows the active record count/date.

## Basic Workflow

1. Open the app and set:
   - ES-DE gamelists root, for example `%APPDATA%\EmuDeck\EmulationStation-DE\ES-DE\gamelists`
   - ROM root, for example `R:\Emulation\roms`
   - Media root, for example `R:\Emulation\storage\downloaded_media`
   - Media mode: `AutoDetect`, `Central`, or `BesideRoms`
   - Export destination and target profile
2. Save settings.
3. Use the Library / Selection tab first. It contains discovery, scan, filters, selection, duplicate-aware auto-select, and preset actions.
4. Click `Discover Systems` for a quick parent-folder scan, then choose whether to scan matched systems, selected systems, or the full ROM directory.
5. Filter, sort, inspect metadata/media, and select games from the Library tab.
6. Use the Library tab's auto-select dropdown for top-N, score threshold, or size-limit selection. Excluded systems and duplicate handling are applied before selection.
7. Use `Dry-run / preview` before `Copy selected`.

## Cache And Logs

Library cache:

```text
%APPDATA%\RomCurator\cache\library_cache.json
```

Logs:

```text
%APPDATA%\RomCurator\logs\Sifter_*.log
```

Each run writes a detailed timestamped log with startup info, configured paths, scan/cache/export/update actions, warnings, timings, theme changes, discovery results, duplicate handling, preset actions, and full exception details. The Tools / Maintenance tab has buttons to open the cache folder, open the log folder, and view the latest log.

Startup loads a valid cache automatically in the background and shows cached games as soon as they are ready. Rescan is not forced unless the cache is missing/invalid, settings roots changed, or you choose a scan action.

## Updating Metacritic

The updater script is bundled at:

```text
tools\Build-Metacritic-Critic-Scores.ps1
```

Use `Update Metacritic ratings` in Tools / Maintenance to run it. The workflow writes a temporary JSONL file, validates it, backs up the previous active file, and replaces the active database only after validation. `Roll back Metacritic ratings` restores the packaged JSONL.

## Themes

The Paths tab has a `Theme` dropdown:

- `System`
- `Dark`
- `Light`

`System` currently uses the dark palette as a safe readable default without inspecting operating-system personalization settings.

## Presets

Selection presets have two formats:

- User preset: personal reuse on this machine. It stores full ROM paths, configured roots, systems, selected game identities, ratings, sizes, and export profile.
- Community preset: shareable. It stores only system IDs, cleaned/normalized names, ratings, genres, players, and rules. Full ROM paths, media paths, drive letters, and user folders are omitted and the saved JSON is checked for path-like strings.

Loading a user preset matches full paths first, then falls back to cleaned name/system. Loading a community preset matches cleaned/normalized title and system aliases. Ambiguous matches choose the best candidate by score, confidence, media, favorite status, and size, and are marked for review.

## Export Safety

Sifter never deletes source ROMs or media and does not modify original `gamelist.xml` files. Export copies go to the configured destination only.

Before copy, the app builds a plan with selected count, total estimated size, per-system size, and destination paths. Copy policies are:

- `Skip`
- `Overwrite`
- `Rename`
- `Compare`

Each export writes:

- `export_manifest.json`
- `export_manifest.csv`
- `export_log.txt`
- `warnings.txt` when needed

## Config Files

Editable project config lives in `data`:

```text
data\system_aliases.json
data\export_profiles.json
```

User settings persist under:

```text
%APPDATA%\RomCurator\settings.json
```

Selection presets persist under:

```text
%APPDATA%\RomCurator\selection-presets
```

## Tests

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

The tests cover:

- name cleaning
- system aliases
- Metacritic JSONL parsing
- rating matching
- gamelist parsing and malformed XML recovery
- ROM/gamelist/media scan matching
- auto-selection
- duplicate grouping and duplicate-skipping auto-select
- quick system discovery
- user/community preset privacy and loading
- export dry-run manifest writing

## Troubleshooting

- If no systems appear, confirm the gamelists root contains `<system>\gamelist.xml`.
- If ROMs appear as orphans, check whether gamelist paths are relative to the ROM system folder.
- If media is missing, try switching media mode between `AutoDetect`, `Central`, and `BesideRoms`.
- If a Metacritic match looks wrong, select the row and use `Edit rating`.
- If a media path is wrong, select the row and use `Set image`.
- If the system dropdown ever shows no rows, clear filters first. Exceptions are logged instead of closing the app.
- For locked or inaccessible files, export logs record the failure and the export continues.

## Current UI Notes

- The bottom status bar has a persisted `Dark Mode` toggle. On uses the dark palette; off uses the light palette.
- Paths is the first tab and is reserved for folder/export path setup.
- The Library systems grid separates item selection from full-system selection. `Select visible` follows active filters; the system `Full` checkbox ignores active filters and exports every copyable item in that system.
- The systems grid shows copyable games, visible games, selected games, ROM size, media size, duplicate groups, and warning counts per system.
- Auto Select uses the `Auto Excl` system toggles. Excluded systems remain visible in the library, but auto-selection skips them.
