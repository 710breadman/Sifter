# Sifter

Sifter is a Windows desktop app for scanning ES-DE / EmulationStation-style ROM libraries, matching gamelist metadata and bundled Metacritic scores, selecting games by quality/size/metadata, and exporting a safe copy to another drive.

It is implemented as a PowerShell + WPF app. It runs with Windows PowerShell 5.1 or PowerShell 7 and keeps the source library read-only.

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

## Updating Metacritic

The updater script is bundled at:

```text
tools\Build-Metacritic-Critic-Scores.ps1
```

Use `Update Metacritic ratings` in Tools / Maintenance to run it. The workflow writes a temporary JSONL file, validates it, backs up the previous active file, and replaces the active database only after validation. `Roll back Metacritic ratings` restores the packaged JSONL.

## Presets

Selection presets have two formats:

- User preset: personal reuse on this machine. It stores full ROM paths, configured roots, systems, selected game identities, ratings, sizes, and export profile.
-  (BETA) Community preset: shareable. It stores only system IDs, cleaned/normalized names, ratings, genres, players, and rules. Full ROM paths, media paths, drive letters, and user folders are omitted and the saved JSON is checked for path-like strings.

## Troubleshooting

- If no systems appear, confirm the gamelists root contains `<system>\gamelist.xml`.
- If ROMs appear as orphans, check whether gamelist paths are relative to the ROM system folder.
- If media is missing, try switching media mode between `AutoDetect`, `Central`, and `BesideRoms`.
- If a Metacritic match looks wrong, select the row and use `Edit rating`.
- If a media path is wrong, select the row and use `Set image`.
- If the system dropdown ever shows no rows, clear filters first. Exceptions are logged instead of closing the app.
- For locked or inaccessible files, export logs record the failure and the export continues.
