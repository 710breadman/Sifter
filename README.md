# Sifter

Sifter is a standalone Windows app for finding, favoriting, and copying the best games from an ES-DE / EmulationStation ROM library.

The app is now a native .NET/WPF executable. It does not need a PowerShell host, loose script package, or zip bundle at runtime.

## What It Does

- Scans `gamelist.xml` files first, so only games that exist in your library drive the results.
- Matches games to bundled or custom Metacritic JSON/JSONL ratings.
- Pre-picks a simple top-rated set per system.
- Keeps systems, genres, and copy options tucked away until you need them.
- Copies selected games in round-robin system order.
- Can mark selected games as favorites by writing `<favorite>true</favorite>` to `gamelist.xml`.
- Creates XML backups before favorite edits.
- Writes copy preview/copy manifests to the app log folder.

## Quick Start

1. Open `Sifter.exe`.
2. Choose:
   - Gamelists folder
   - ROMs folder
   - Export folder
3. Click **Discover Systems**.
4. Click **Scan Library**.
5. Review the picked games.
6. Click **Preview Copy** first, then **Copy Selected** when it looks right.

Use **Add Selected To Favorites** when you want the selected games marked as favorites in ES-DE.

## Safety

Sifter does not delete source ROMs. Copying writes to your chosen export folder. Favorite edits are the only operation that modifies existing library metadata, and Sifter creates a `.bak_yyyyMMdd_HHmmss` backup before saving each edited `gamelist.xml`.

## Build

Install the .NET SDK requested by `global.json`, then run:

```powershell
dotnet test tests\Sifter.Core.Tests\Sifter.Core.Tests.csproj
.\tools\Publish-Sifter-DotNet.ps1 -Clean
```

The standalone executable is published to:

```text
dist\Sifter-Standalone\Sifter.exe
```

The current self-contained Windows build is about 63 MB. Most of that is the bundled .NET desktop runtime; WPF does not support trimming, so the app keeps trimming disabled for reliability.

Crash logs, when Sifter can write them, go to:

```text
%APPDATA%\RomCurator\logs
```

## Notes

`tools\Build-Metacritic-Critic-Scores.ps1` is kept as an optional data-maintenance helper. It is not needed to run Sifter.
