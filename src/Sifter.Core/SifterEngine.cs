using System.Globalization;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml;

namespace Sifter.Core;

public sealed class SifterEngine
{
    private const string BundledRatingsResource = "Sifter.Core.Data.metacritic_game_critic_scores.jsonl";

    private static readonly Dictionary<string, string[]> AliasSource = new(StringComparer.OrdinalIgnoreCase)
    {
        ["gc"] = ["gamecube", "ngc", "nintendo gamecube"],
        ["genesis"] = ["megadrive", "md", "sega genesis", "sega megadrive"],
        ["xbox360"] = ["x360", "xbox 360", "xb360", "360"],
        ["psx"] = ["ps1", "playstation", "playstation 1", "sony playstation"],
        ["n64"] = ["nintendo64", "nintendo 64"],
        ["snes"] = ["sfc", "super nintendo", "super famicom"],
        ["nes"] = ["famicom", "nintendo entertainment system"],
        ["arcade"] = ["mame", "fbneo", "fba", "finalburn neo"],
        ["tg16"] = ["pcengine", "pc engine", "turbografx16", "turbografx-16"],
        ["dreamcast"] = ["dc", "sega dreamcast"],
        ["switch"] = ["nsw", "nintendo switch"],
        ["wiiu"] = ["wii u", "nintendo wii u"],
        ["3ds"] = ["n3ds", "nintendo 3ds"],
        ["nds"] = ["ds", "nintendo ds"],
        ["ps2"] = ["playstation2", "playstation 2"],
        ["ps3"] = ["playstation3", "playstation 3"],
        ["psp"] = ["playstation portable"],
        ["gb"] = ["game boy", "gameboy"],
        ["gbc"] = ["game boy color", "gameboy color"],
        ["gba"] = ["game boy advance", "gameboy advance"],
        ["wii"] = ["nintendo wii"],
        ["xbox"] = ["original xbox", "xbox classic", "og xbox"],
        ["saturn"] = ["sega saturn"],
        ["mastersystem"] = ["master system", "sega master system"],
        ["gamegear"] = ["game gear", "sega game gear"],
    };

    private static readonly Dictionary<string, string> DisplayNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ["gb"] = "Game Boy",
        ["gbc"] = "Game Boy Color",
        ["gba"] = "Game Boy Advance",
        ["nes"] = "NES",
        ["snes"] = "SNES",
        ["n64"] = "Nintendo 64",
        ["gc"] = "GameCube",
        ["wii"] = "Wii",
        ["wiiu"] = "Wii U",
        ["switch"] = "Nintendo Switch",
        ["psx"] = "PlayStation",
        ["ps2"] = "PlayStation 2",
        ["ps3"] = "PlayStation 3",
        ["psp"] = "PSP",
        ["psvita"] = "PlayStation Vita",
        ["xbox"] = "Xbox",
        ["xbox360"] = "Xbox 360",
        ["dreamcast"] = "Dreamcast",
        ["saturn"] = "Saturn",
        ["genesis"] = "Genesis",
        ["megadrive"] = "Mega Drive",
        ["mastersystem"] = "Master System",
        ["gamegear"] = "Game Gear",
        ["mame"] = "MAME",
        ["arcade"] = "Arcade",
        ["fbneo"] = "FinalBurn Neo",
        ["nds"] = "Nintendo DS",
        ["3ds"] = "Nintendo 3DS",
        ["dos"] = "DOS",
        ["pc"] = "PC",
    };

    private static readonly Dictionary<string, string[]> GenreBuckets = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Sports"] =
        [
            "sport", "sports", "football", "soccer", "basketball", "baseball", "hockey",
            "golf", "tennis", "volleyball", "boxing", "wrestling", "mma", "ufc", "wwe",
            "skate", "skating", "snowboard", "ski", "olympic", "fishing", "bowling",
            "billiards", "pool", "rugby", "cricket", "nascar", "fifa", "nba", "nfl",
            "nhl", "mlb", "madden", "pes", "pro evolution"
        ],
        ["Racing"] = ["racing", "driving", "rally", "kart", "motocross", "motorcycle", "formula", "motorsport", "nascar", "speed"],
        ["Fighting"] = ["fighting", "fighter", "beat em up", "beat-em-up", "brawler", "boxing", "wrestling", "martial", "combat"],
        ["Shooter"] = ["shooter", "fps", "first person shooter", "third person shooter", "shoot em up", "shoot-em-up", "shmup", "gun", "light gun"],
        ["RPG"] = ["rpg", "role playing", "role-playing", "jrpg", "action rpg", "tactical rpg"],
        ["Strategy"] = ["strategy", "tactics", "tactical", "rts", "turn based", "turn-based"],
        ["Puzzle"] = ["puzzle", "logic", "matching", "trivia"],
        ["Simulation"] = ["simulation", "simulator", "sim", "management", "tycoon"],
        ["Platformer"] = ["platform", "platformer", "2d platform", "3d platform"],
        ["Rhythm"] = ["rhythm", "music", "dance", "karaoke"],
        ["Board/Card/Casino"] = ["board", "card", "casino", "poker", "chess", "mahjong", "pinball"],
        ["Educational"] = ["educational", "edutainment", "learning"],
    };

    private static readonly HashSet<string> NonRomExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".mp4", ".mkv", ".avi", ".mov",
        ".xml", ".txt", ".nfo", ".csv", ".json", ".srt", ".sub"
    };

    private readonly AppPaths appPaths;
    private readonly SystemAliasMap aliases = SystemAliasMap.FromDictionary(AliasSource);

    public SifterEngine(AppPaths appPaths)
    {
        this.appPaths = appPaths;
        this.appPaths.EnsureBaseDirectories();
    }

    public static IReadOnlyList<string> BroadGenres => GenreBuckets.Keys.ToArray();

    public SifterSettings LoadSettings()
    {
        try
        {
            if (!File.Exists(appPaths.SettingsFile))
            {
                return new SifterSettings();
            }

            string json = File.ReadAllText(appPaths.SettingsFile);
            return JsonSerializer.Deserialize<SifterSettings>(json) ?? new SifterSettings();
        }
        catch
        {
            return new SifterSettings();
        }
    }

    public void SaveSettings(SifterSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(appPaths.SettingsFile)!);
        string json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(appPaths.SettingsFile, json);
    }

    public IReadOnlyList<SystemChoice> DiscoverSystems(SifterSettings settings, IProgress<string>? progress = null)
    {
        if (string.IsNullOrWhiteSpace(settings.GamelistsRoot) || !Directory.Exists(settings.GamelistsRoot))
        {
            return [];
        }

        progress?.Report("Finding gamelist.xml files...");

        var files = Directory.EnumerateFiles(settings.GamelistsRoot, "gamelist.xml", SearchOption.AllDirectories)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var systems = new List<SystemChoice>();
        foreach (string file in files)
        {
            string folderKey = Path.GetFileName(Path.GetDirectoryName(file) ?? string.Empty);
            string canonicalKey = aliases.Resolve(folderKey);
            string displayName = GetDisplayName(canonicalKey);
            string romRoot = ResolveRomRoot(settings.RomsRoot, canonicalKey, folderKey);
            bool hasRomFolder = Directory.Exists(romRoot);
            int gameCount = CountGames(file);

            systems.Add(new SystemChoice(
                canonicalKey,
                displayName,
                file,
                romRoot,
                gameCount,
                hasRomFolder));
        }

        return systems
            .GroupBy(system => system.GamelistPath, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderBy(system => system.DisplayName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(system => system.Key, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public IReadOnlyList<LibraryGame> ScanLibrary(SifterSettings settings, IProgress<string>? progress = null)
    {
        ValidateScanSettings(settings);

        IReadOnlyList<SystemChoice> discovered = DiscoverSystems(settings, progress);
        HashSet<string> selectedSystems = settings.SelectedSystems.Count == 0
            ? new HashSet<string>(discovered.Select(system => system.Key), StringComparer.OrdinalIgnoreCase)
            : new HashSet<string>(settings.SelectedSystems.Select(aliases.Resolve), StringComparer.OrdinalIgnoreCase);

        var activeSystems = discovered
            .Where(system => selectedSystems.Contains(system.Key))
            .ToArray();

        if (activeSystems.Length == 0)
        {
            throw new InvalidOperationException("No systems are selected. Click Discover, choose at least one system, then scan.");
        }

        progress?.Report("Loading Metacritic ratings...");
        RatingIndex ratingIndex = RatingIndex.Build(LoadRatings(settings.RatingFilePath, progress));
        var games = new List<LibraryGame>();

        foreach (SystemChoice system in activeSystems)
        {
            progress?.Report($"Scanning {system.DisplayName}...");
            var inventory = BuildFileInventory(system.RomRoot);
            XmlDocument? doc = TryLoadGamelist(system.GamelistPath, out string xmlWarning);
            if (doc is null)
            {
                games.Add(new LibraryGame
                {
                    SystemKey = system.Key,
                    SystemName = system.DisplayName,
                    GamelistPath = system.GamelistPath,
                    RomSystemRoot = system.RomRoot,
                    GameName = $"{system.DisplayName} gamelist could not be read",
                    Issues = xmlWarning
                });
                continue;
            }

            foreach (XmlNode gameNode in SelectGameNodes(doc))
            {
                string xmlPathText = GetChildText(gameNode, "path");
                string xmlName = GetChildText(gameNode, "name");
                string name = string.IsNullOrWhiteSpace(xmlName)
                    ? CleanLeafName(xmlPathText)
                    : xmlName.Trim();

                if (string.IsNullOrWhiteSpace(name))
                {
                    continue;
                }

                string genre = GetChildText(gameNode, "genre");
                string favorite = GetChildText(gameNode, "favorite");
                IReadOnlyList<string> files = ResolveSourceFiles(system.RomRoot, xmlPathText, name, inventory);
                string firstFile = files.FirstOrDefault() ?? string.Empty;
                string relativePath = string.IsNullOrWhiteSpace(firstFile)
                    ? CleanRelativePath(xmlPathText)
                    : GetSafeRelativePath(system.RomRoot, firstFile);

                RatingMatch? match = ratingIndex.FindBest(name, xmlPathText, system.Key, aliases);
                bool excluded = match is not null && IsExcludedByGenre(settings.ExcludedGenres, name, genre, match.Record.Genres);

                games.Add(new LibraryGame
                {
                    SystemKey = system.Key,
                    SystemName = system.DisplayName,
                    GameName = name,
                    GamelistPath = system.GamelistPath,
                    XmlName = xmlName,
                    XmlPathText = xmlPathText,
                    RomSystemRoot = system.RomRoot,
                    RelativePath = relativePath,
                    RomPath = firstFile,
                    SourceFiles = files,
                    Genre = genre,
                    Favorite = favorite,
                    CriticScore = match?.Record.Score,
                    RatingTitle = match?.Record.Title ?? string.Empty,
                    RatingPlatform = match?.Record.Platform ?? string.Empty,
                    RatingGenres = match?.Record.Genres ?? string.Empty,
                    MatchConfidence = match?.Confidence ?? 0,
                    MatchMethod = match?.Method ?? string.Empty,
                    Issues = excluded ? "Filtered by genre" : string.Empty
                });
            }
        }

        ApplyDefaultSelection(games, settings);
        progress?.Report($"Scan complete: {games.Count} games found.");
        return games;
    }

    public ExportResult ExportSelected(SifterSettings settings, IEnumerable<LibraryGame> games, bool dryRun, IProgress<string>? progress = null)
    {
        if (string.IsNullOrWhiteSpace(settings.ExportRoot))
        {
            throw new InvalidOperationException("Choose an export folder first.");
        }

        Directory.CreateDirectory(settings.ExportRoot);
        Directory.CreateDirectory(appPaths.LogDirectory);

        var selected = games
            .Where(game => game.Selected && game.SourceFiles.Count > 0 && string.IsNullOrWhiteSpace(game.Issues))
            .GroupBy(game => game.SystemKey, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(
                group => group.Key,
                group => group
                    .OrderByDescending(game => game.CriticScore ?? -1)
                    .ThenBy(game => game.GameName, StringComparer.OrdinalIgnoreCase)
                    .ToList(),
                StringComparer.OrdinalIgnoreCase);

        var orderedSystems = GetSystemOrder(settings, selected.Keys);
        var queue = BuildRoundRobinQueue(selected, orderedSystems);
        string stamp = DateTime.Now.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture);
        string manifestPath = Path.Combine(appPaths.LogDirectory, dryRun ? $"preview_{stamp}.csv" : $"copy_{stamp}.csv");
        var rows = new List<string> { "Action,System,Game,Source,Destination,Bytes,Message" };
        var messages = new List<string>();
        int copiedFiles = 0;
        int skipped = 0;
        int errors = 0;
        long bytes = 0;

        progress?.Report(dryRun ? "Building copy preview..." : "Copying selected games...");

        foreach (LibraryGame game in queue)
        {
            foreach (string source in game.SourceFiles)
            {
                try
                {
                    if (!File.Exists(source))
                    {
                        errors++;
                        rows.Add(ToCsv("Missing", game.SystemName, game.GameName, source, string.Empty, "0", "Source file was not found."));
                        continue;
                    }

                    string relative = GetSafeRelativePath(game.RomSystemRoot, source);
                    string destination = Path.Combine(settings.ExportRoot, game.SystemKey, relative);
                    long size = new FileInfo(source).Length;
                    bytes += size;

                    if (File.Exists(destination) && !settings.OverwriteExisting)
                    {
                        skipped++;
                        rows.Add(ToCsv("Skipped", game.SystemName, game.GameName, source, destination, size.ToString(CultureInfo.InvariantCulture), "Already exists."));
                        continue;
                    }

                    if (!dryRun)
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                        File.Copy(source, destination, overwrite: settings.OverwriteExisting);
                    }

                    copiedFiles++;
                    rows.Add(ToCsv(dryRun ? "WouldCopy" : "Copied", game.SystemName, game.GameName, source, destination, size.ToString(CultureInfo.InvariantCulture), string.Empty));
                }
                catch (Exception ex)
                {
                    errors++;
                    rows.Add(ToCsv("Error", game.SystemName, game.GameName, source, string.Empty, "0", ex.Message));
                }
            }
        }

        File.WriteAllLines(manifestPath, rows, Encoding.UTF8);
        messages.Add($"{(dryRun ? "Previewed" : "Copied")} {copiedFiles} file(s) from {queue.Count} game(s).");
        if (skipped > 0)
        {
            messages.Add($"Skipped {skipped} existing file(s).");
        }

        if (errors > 0)
        {
            messages.Add($"{errors} error(s). See the manifest for details.");
        }

        messages.Add($"Manifest: {manifestPath}");
        return new ExportResult(dryRun, queue.Count, copiedFiles, skipped, errors, bytes, manifestPath, messages);
    }

    public FavoriteResult SaveSelectedFavorites(IEnumerable<LibraryGame> games, IProgress<string>? progress = null)
    {
        var selected = games
            .Where(game => game.Selected && !string.IsNullOrWhiteSpace(game.GamelistPath))
            .GroupBy(game => game.GamelistPath, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var backups = new List<string>();
        var messages = new List<string>();
        int systems = 0;
        int changed = 0;
        int already = 0;
        int errors = 0;
        string stamp = DateTime.Now.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture);

        foreach (var group in selected)
        {
            string gamelistPath = group.Key;
            progress?.Report($"Updating favorites in {Path.GetFileName(Path.GetDirectoryName(gamelistPath))}...");

            try
            {
                XmlDocument? doc = TryLoadGamelist(gamelistPath, out string warning);
                if (doc is null)
                {
                    errors++;
                    messages.Add($"{gamelistPath}: {warning}");
                    continue;
                }

                int changedInFile = 0;
                foreach (LibraryGame game in group)
                {
                    XmlNode? node = FindGameNode(doc, game);
                    if (node is null)
                    {
                        errors++;
                        messages.Add($"{game.GameName}: could not find matching XML node.");
                        continue;
                    }

                    string favorite = GetChildText(node, "favorite");
                    if (IsTrue(favorite))
                    {
                        already++;
                        continue;
                    }

                    SetChildText(doc, node, "favorite", "true");
                    changed++;
                    changedInFile++;
                }

                if (changedInFile > 0)
                {
                    string backup = $"{gamelistPath}.bak_{stamp}";
                    File.Copy(gamelistPath, backup, overwrite: true);
                    SaveXmlDocument(doc, gamelistPath);
                    backups.Add(backup);
                    systems++;
                }
            }
            catch (Exception ex)
            {
                errors++;
                messages.Add($"{gamelistPath}: {ex.Message}");
            }
        }

        messages.Insert(0, $"Added {changed} favorite marker(s). {already} already existed.");
        return new FavoriteResult(systems, changed, already, errors, backups, messages);
    }

    public void PickTopGames(IReadOnlyList<LibraryGame> games, SifterSettings settings)
    {
        ApplyDefaultSelection(games, settings);
    }

    private static void ValidateScanSettings(SifterSettings settings)
    {
        if (string.IsNullOrWhiteSpace(settings.GamelistsRoot) || !Directory.Exists(settings.GamelistsRoot))
        {
            throw new InvalidOperationException("Choose the folder that contains your system gamelist folders.");
        }

        if (string.IsNullOrWhiteSpace(settings.RomsRoot) || !Directory.Exists(settings.RomsRoot))
        {
            throw new InvalidOperationException("Choose the folder that contains your ROM system folders.");
        }
    }

    private static string ResolveRomRoot(string root, string canonicalKey, string folderKey)
    {
        if (string.IsNullOrWhiteSpace(root))
        {
            return string.Empty;
        }

        string canonical = Path.Combine(root, canonicalKey);
        if (Directory.Exists(canonical))
        {
            return canonical;
        }

        string raw = Path.Combine(root, folderKey);
        if (Directory.Exists(raw))
        {
            return raw;
        }

        if (AliasSource.TryGetValue(canonicalKey, out string[]? aliasList))
        {
            foreach (string alias in aliasList)
            {
                string candidate = Path.Combine(root, alias);
                if (Directory.Exists(candidate))
                {
                    return candidate;
                }
            }
        }

        return canonical;
    }

    private static int CountGames(string gamelistPath)
    {
        XmlDocument? doc = TryLoadGamelist(gamelistPath, out _);
        return doc is null ? 0 : SelectGameNodes(doc).Count;
    }

    private static XmlDocument? TryLoadGamelist(string path, out string warning)
    {
        warning = string.Empty;

        try
        {
            var doc = new XmlDocument { PreserveWhitespace = false };
            doc.Load(path);
            return doc;
        }
        catch (Exception first)
        {
            try
            {
                string text = File.ReadAllText(path);
                string? recovered = ExtractGamelistXml(text);
                if (recovered is null)
                {
                    warning = first.Message;
                    return null;
                }

                var doc = new XmlDocument { PreserveWhitespace = false };
                doc.LoadXml(recovered);
                warning = "Recovered malformed XML.";
                return doc;
            }
            catch (Exception second)
            {
                warning = second.Message;
                return null;
            }
        }
    }

    private static string? ExtractGamelistXml(string text)
    {
        int start = text.IndexOf("<gameList", StringComparison.OrdinalIgnoreCase);
        int end = text.LastIndexOf("</gameList>", StringComparison.OrdinalIgnoreCase);
        if (start >= 0 && end > start)
        {
            return text[start..(end + "</gameList>".Length)];
        }

        var matches = Regex.Matches(text, @"<game\b[\s\S]*?</game>", RegexOptions.IgnoreCase);
        if (matches.Count == 0)
        {
            return null;
        }

        var builder = new StringBuilder("<gameList>");
        foreach (Match match in matches)
        {
            builder.Append(match.Value);
        }

        builder.Append("</gameList>");
        return builder.ToString();
    }

    private static XmlNodeList SelectGameNodes(XmlDocument doc)
    {
        return doc.SelectNodes("//game") ?? throw new InvalidOperationException("Could not query gamelist games.");
    }

    private static string GetChildText(XmlNode node, string childName)
    {
        return node.SelectSingleNode(childName)?.InnerText.Trim() ?? string.Empty;
    }

    private static void SetChildText(XmlDocument doc, XmlNode node, string childName, string text)
    {
        XmlNode? child = node.SelectSingleNode(childName);
        if (child is null)
        {
            child = doc.CreateElement(childName);
            node.AppendChild(child);
        }

        child.InnerText = text;
    }

    private static void SaveXmlDocument(XmlDocument doc, string path)
    {
        var settings = new XmlWriterSettings
        {
            Indent = true,
            NewLineChars = "\r\n",
            Encoding = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false)
        };

        using XmlWriter writer = XmlWriter.Create(path, settings);
        doc.Save(writer);
    }

    private static XmlNode? FindGameNode(XmlDocument doc, LibraryGame game)
    {
        foreach (XmlNode node in SelectGameNodes(doc))
        {
            string path = GetChildText(node, "path");
            string name = GetChildText(node, "name");

            if (!string.IsNullOrWhiteSpace(game.XmlPathText) &&
                path.Equals(game.XmlPathText, StringComparison.OrdinalIgnoreCase))
            {
                return node;
            }

            if (!string.IsNullOrWhiteSpace(game.XmlName) &&
                name.Equals(game.XmlName, StringComparison.OrdinalIgnoreCase))
            {
                return node;
            }
        }

        return null;
    }

    private static FileInventory BuildFileInventory(string romRoot)
    {
        var inventory = new FileInventory();
        if (string.IsNullOrWhiteSpace(romRoot) || !Directory.Exists(romRoot))
        {
            return inventory;
        }

        foreach (string file in Directory.EnumerateFiles(romRoot, "*", SearchOption.AllDirectories))
        {
            string extension = Path.GetExtension(file);
            if (NonRomExtensions.Contains(extension))
            {
                continue;
            }

            string name = CleanLeafName(file);
            string key = NormalizeKey(name);
            string compact = Compact(key);
            inventory.Add(key, compact, file);
        }

        return inventory;
    }

    private static IReadOnlyList<string> ResolveSourceFiles(string romRoot, string xmlPathText, string gameName, FileInventory inventory)
    {
        string cleanedPath = CleanRelativePath(xmlPathText);
        var directCandidates = new List<string>();

        if (!string.IsNullOrWhiteSpace(xmlPathText))
        {
            string trimmed = xmlPathText.Trim().Trim('"');
            if (Path.IsPathRooted(trimmed))
            {
                directCandidates.Add(trimmed);
            }

            if (!string.IsNullOrWhiteSpace(romRoot))
            {
                directCandidates.Add(Path.Combine(romRoot, cleanedPath));
            }
        }

        foreach (string candidate in directCandidates)
        {
            if (File.Exists(candidate))
            {
                return [candidate];
            }

            if (Directory.Exists(candidate))
            {
                return Directory.EnumerateFiles(candidate, "*", SearchOption.AllDirectories)
                    .Where(file => !NonRomExtensions.Contains(Path.GetExtension(file)))
                    .OrderBy(file => file, StringComparer.OrdinalIgnoreCase)
                    .ToArray();
            }
        }

        string pathKey = NormalizeKey(CleanLeafName(xmlPathText));
        string nameKey = NormalizeKey(gameName);

        foreach (string key in new[] { pathKey, nameKey }.Where(key => !string.IsNullOrWhiteSpace(key)).Distinct(StringComparer.OrdinalIgnoreCase))
        {
            IReadOnlyList<string> found = inventory.Find(key, Compact(key));
            if (found.Count > 0)
            {
                return found;
            }
        }

        return [];
    }

    private IReadOnlyList<RatingRecord> LoadRatings(string ratingFilePath, IProgress<string>? progress)
    {
        Stream stream;
        string sourceName;

        if (!string.IsNullOrWhiteSpace(ratingFilePath) && File.Exists(ratingFilePath))
        {
            stream = File.OpenRead(ratingFilePath);
            sourceName = ratingFilePath;
        }
        else
        {
            stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(BundledRatingsResource)
                ?? throw new InvalidOperationException("Bundled Metacritic ratings were not found in the app.");
            sourceName = "bundled ratings";
        }

        progress?.Report($"Reading {sourceName}...");
        using (stream)
        using (var reader = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true))
        {
            string all = reader.ReadToEnd();
            return ParseRatingText(all);
        }
    }

    private static IReadOnlyList<RatingRecord> ParseRatingText(string text)
    {
        var records = new List<RatingRecord>();
        string trimmed = text.TrimStart();

        if (trimmed.StartsWith("[", StringComparison.Ordinal))
        {
            using JsonDocument doc = JsonDocument.Parse(text);
            foreach (JsonElement element in doc.RootElement.EnumerateArray())
            {
                RatingRecord? record = RatingRecord.TryCreate(element);
                if (record is not null)
                {
                    records.Add(record);
                }
            }

            return records;
        }

        using var reader = new StringReader(text);
        while (reader.ReadLine() is { } line)
        {
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            try
            {
                using JsonDocument doc = JsonDocument.Parse(line);
                RatingRecord? record = RatingRecord.TryCreate(doc.RootElement);
                if (record is not null)
                {
                    records.Add(record);
                }
            }
            catch
            {
                // Skip malformed rating records; the source file is external and may be mixed.
            }
        }

        return records;
    }

    private static bool IsExcludedByGenre(IEnumerable<string> excludedGenres, string gameName, string xmlGenre, string ratingGenres)
    {
        string haystack = NormalizePlainText($"{gameName} {xmlGenre} {ratingGenres}");
        foreach (string bucket in excludedGenres)
        {
            if (!GenreBuckets.TryGetValue(bucket, out string[]? keywords))
            {
                continue;
            }

            foreach (string keyword in keywords)
            {
                string key = NormalizePlainText(keyword);
                if (haystack.Equals(key, StringComparison.OrdinalIgnoreCase) ||
                    haystack.Contains($" {key} ", StringComparison.OrdinalIgnoreCase) ||
                    haystack.StartsWith($"{key} ", StringComparison.OrdinalIgnoreCase) ||
                    haystack.EndsWith($" {key}", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
        }

        return false;
    }

    private static void ApplyDefaultSelection(IReadOnlyList<LibraryGame> games, SifterSettings settings)
    {
        foreach (LibraryGame game in games)
        {
            game.Selected = false;
        }

        foreach (var group in games
            .Where(game => game.CriticScore >= settings.MinimumScore && game.SourceFiles.Count > 0 && string.IsNullOrWhiteSpace(game.Issues))
            .GroupBy(game => game.SystemKey, StringComparer.OrdinalIgnoreCase))
        {
            IEnumerable<LibraryGame> candidates = group;
            if (settings.ExcludeDuplicates)
            {
                candidates = candidates
                    .GroupBy(game => NormalizeKey(game.GameName), StringComparer.OrdinalIgnoreCase)
                    .Select(duplicateGroup => duplicateGroup
                        .OrderByDescending(game => game.CriticScore ?? -1)
                        .ThenByDescending(game => IsTrue(game.Favorite))
                        .ThenBy(game => game.GameName, StringComparer.OrdinalIgnoreCase)
                        .First());
            }

            foreach (LibraryGame game in candidates
                .OrderByDescending(game => game.CriticScore ?? -1)
                .ThenBy(game => game.GameName, StringComparer.OrdinalIgnoreCase)
                .Take(Math.Max(1, settings.TopPerSystem)))
            {
                game.Selected = true;
            }
        }
    }

    private static IReadOnlyList<string> GetSystemOrder(SifterSettings settings, IEnumerable<string> fallbackSystems)
    {
        var ordered = settings.SelectedSystems.Count > 0
            ? settings.SelectedSystems.Select(SystemAliasMap.Normalize).ToList()
            : [];

        foreach (string key in fallbackSystems.OrderBy(key => key, StringComparer.OrdinalIgnoreCase))
        {
            string normalized = SystemAliasMap.Normalize(key);
            if (!ordered.Contains(normalized, StringComparer.OrdinalIgnoreCase))
            {
                ordered.Add(normalized);
            }
        }

        return ordered;
    }

    private static IReadOnlyList<LibraryGame> BuildRoundRobinQueue(
        IReadOnlyDictionary<string, List<LibraryGame>> groups,
        IReadOnlyList<string> systemOrder)
    {
        var queue = new List<LibraryGame>();
        var positions = groups.Keys.ToDictionary(key => key, _ => 0, StringComparer.OrdinalIgnoreCase);
        bool added;

        do
        {
            added = false;
            foreach (string orderedKey in systemOrder)
            {
                string? key = groups.Keys.FirstOrDefault(candidate => SystemAliasMap.Normalize(candidate) == orderedKey);
                if (key is null)
                {
                    continue;
                }

                int position = positions[key];
                if (position < groups[key].Count)
                {
                    queue.Add(groups[key][position]);
                    positions[key] = position + 1;
                    added = true;
                }
            }
        }
        while (added);

        return queue;
    }

    private static string GetDisplayName(string key)
    {
        return DisplayNames.TryGetValue(key, out string? displayName) ? displayName : key;
    }

    private static string CleanLeafName(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        string normalized = text.Trim().Trim('"').Replace('\\', '/');
        string leaf = normalized.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault() ?? normalized;
        try
        {
            string withoutExtension = Path.GetFileNameWithoutExtension(leaf);
            return string.IsNullOrWhiteSpace(withoutExtension) ? leaf : withoutExtension;
        }
        catch
        {
            return leaf;
        }
    }

    private static string CleanRelativePath(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        string cleaned = text.Trim().Trim('"').Replace('/', Path.DirectorySeparatorChar);
        while (cleaned.StartsWith($".{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
        {
            cleaned = cleaned[2..];
        }

        return cleaned.TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    private static string GetSafeRelativePath(string root, string path)
    {
        if (string.IsNullOrWhiteSpace(root) || string.IsNullOrWhiteSpace(path))
        {
            return Path.GetFileName(path);
        }

        try
        {
            string relative = Path.GetRelativePath(root, path);
            if (relative.StartsWith("..", StringComparison.Ordinal))
            {
                return Path.GetFileName(path);
            }

            return relative;
        }
        catch
        {
            return Path.GetFileName(path);
        }
    }

    private static string NormalizeKey(string text)
    {
        return GameNameNormalizer.NormalizeKey(text);
    }

    private static string NormalizePlainText(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        string decomposed = text.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);
        foreach (char c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            {
                builder.Append(c);
            }
        }

        string value = builder.ToString().Normalize(NormalizationForm.FormC).ToLowerInvariant();
        value = Regex.Replace(value, @"[^a-z0-9]+", " ");
        value = Regex.Replace(value, @"\s+", " ");
        return value.Trim();
    }

    private static string Compact(string text)
    {
        return Regex.Replace(text.ToLowerInvariant(), @"[^a-z0-9]+", string.Empty);
    }

    private static bool IsTrue(string text)
    {
        return text.Trim().Equals("true", StringComparison.OrdinalIgnoreCase) ||
               text.Trim().Equals("1", StringComparison.OrdinalIgnoreCase) ||
               text.Trim().Equals("yes", StringComparison.OrdinalIgnoreCase);
    }

    private static string ToCsv(params string[] values)
    {
        return string.Join(",", values.Select(value => $"\"{value.Replace("\"", "\"\"", StringComparison.Ordinal)}\""));
    }

    private sealed class FileInventory
    {
        private readonly Dictionary<string, List<string>> byKey = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, List<string>> byCompact = new(StringComparer.OrdinalIgnoreCase);

        public void Add(string key, string compact, string file)
        {
            AddTo(byKey, key, file);
            AddTo(byCompact, compact, file);
        }

        public IReadOnlyList<string> Find(string key, string compact)
        {
            if (byKey.TryGetValue(key, out List<string>? exact))
            {
                return exact;
            }

            if (byCompact.TryGetValue(compact, out List<string>? compactMatches))
            {
                return compactMatches;
            }

            return [];
        }

        private static void AddTo(Dictionary<string, List<string>> index, string key, string file)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return;
            }

            if (!index.TryGetValue(key, out List<string>? files))
            {
                files = [];
                index[key] = files;
            }

            files.Add(file);
        }
    }

    private sealed record RatingMatch(RatingRecord Record, double Confidence, string Method);

    private sealed record RatingRecord(
        string Title,
        double Score,
        string Platform,
        string Genres,
        IReadOnlyList<string> Keys)
    {
        public static RatingRecord? TryCreate(JsonElement element)
        {
            string title = GetFirstText(element, "title", "name", "game", "game_title", "gameTitle", "game_name");
            if (string.IsNullOrWhiteSpace(title))
            {
                return null;
            }

            double? score = GetScore(element);
            if (!score.HasValue)
            {
                return null;
            }

            string platform = GetFirstText(element, "platform", "system", "console", "platform_name", "platformName");
            string genres = GetFirstText(element, "genres", "genre", "primary_genre", "primaryGenre");
            return new RatingRecord(title, score.Value, platform, genres, GetTitleKeys(title));
        }

        private static string GetFirstText(JsonElement element, params string[] names)
        {
            foreach (string name in names)
            {
                foreach (JsonProperty property in element.EnumerateObject())
                {
                    if (!property.Name.Equals(name, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    string value = JsonValueToText(property.Value);
                    if (!string.IsNullOrWhiteSpace(value))
                    {
                        return value.Trim();
                    }
                }
            }

            return string.Empty;
        }

        private static double? GetScore(JsonElement element)
        {
            foreach (string name in new[] { "critic_score", "criticScore", "critic score", "metascore", "meta_score", "metaScore", "score", "rating" })
            {
                foreach (JsonProperty property in element.EnumerateObject())
                {
                    if (!property.Name.Equals(name, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    if (property.Value.ValueKind == JsonValueKind.Number &&
                        property.Value.TryGetDouble(out double numeric))
                    {
                        return numeric <= 10 ? numeric * 10 : numeric;
                    }

                    string text = JsonValueToText(property.Value);
                    Match match = Regex.Match(text, @"\d+(\.\d+)?");
                    if (match.Success &&
                        double.TryParse(match.Value, NumberStyles.Float, CultureInfo.InvariantCulture, out double parsed))
                    {
                        return parsed <= 10 ? parsed * 10 : parsed;
                    }
                }
            }

            return null;
        }

        private static string JsonValueToText(JsonElement value)
        {
            return value.ValueKind switch
            {
                JsonValueKind.String => value.GetString() ?? string.Empty,
                JsonValueKind.Number => value.ToString(),
                JsonValueKind.Array => string.Join("; ", value.EnumerateArray().Select(JsonValueToText)),
                JsonValueKind.Object => value.ToString(),
                _ => string.Empty
            };
        }

        private static IReadOnlyList<string> GetTitleKeys(string title)
        {
            var keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            AddKey(keys, title);
            string noBrackets = Regex.Replace(title, @"[\(\[\{].*?[\)\]\}]", " ");
            AddKey(keys, noBrackets);

            foreach (string separator in new[] { " - ", ": ", " -- " })
            {
                int index = noBrackets.IndexOf(separator, StringComparison.Ordinal);
                if (index > 0)
                {
                    AddKey(keys, noBrackets[..index]);
                }
            }

            return keys.ToArray();
        }

        private static void AddKey(HashSet<string> keys, string value)
        {
            string key = NormalizeKey(value);
            if (!string.IsNullOrWhiteSpace(key))
            {
                keys.Add(key);
            }
        }
    }

    private sealed class RatingIndex
    {
        private readonly Dictionary<string, List<RatingRecord>> exact = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, List<RatingRecord>> compact = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, List<RatingRecord>> token = new(StringComparer.OrdinalIgnoreCase);

        private RatingIndex()
        {
        }

        public static RatingIndex Build(IReadOnlyList<RatingRecord> records)
        {
            var index = new RatingIndex();
            foreach (RatingRecord record in records)
            {
                foreach (string key in record.Keys)
                {
                    Add(index.exact, key, record);
                    Add(index.compact, Compact(key), record);
                    foreach (string token in Tokenize(key))
                    {
                        Add(index.token, token, record);
                    }
                }
            }

            return index;
        }

        public RatingMatch? FindBest(string gameName, string gamePath, string systemKey, SystemAliasMap aliases)
        {
            var keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            AddCandidateKey(keys, gameName);
            AddCandidateKey(keys, CleanLeafName(gamePath));

            var directCandidates = new List<RatingRecord>();
            foreach (string key in keys)
            {
                if (exact.TryGetValue(key, out List<RatingRecord>? exactRecords))
                {
                    directCandidates.AddRange(exactRecords);
                }

                if (compact.TryGetValue(Compact(key), out List<RatingRecord>? compactRecords))
                {
                    directCandidates.AddRange(compactRecords);
                }
            }

            if (directCandidates.Count > 0)
            {
                RatingRecord record = PickBest(directCandidates, systemKey, aliases);
                return new RatingMatch(record, 1.0, "Exact");
            }

            var fuzzyCandidates = new HashSet<RatingRecord>();
            foreach (string candidateKey in keys)
            {
                foreach (string candidateToken in Tokenize(candidateKey))
                {
                    if (token.TryGetValue(candidateToken, out List<RatingRecord>? tokenRecords))
                    {
                        foreach (RatingRecord record in tokenRecords)
                        {
                            fuzzyCandidates.Add(record);
                        }
                    }
                }
            }

            if (fuzzyCandidates.Count == 0)
            {
                return null;
            }

            var ranked = fuzzyCandidates
                .Select(record => new
                {
                    Record = record,
                    Confidence = keys.SelectMany(key => record.Keys.Select(recordKey => GetSimilarity(key, recordKey))).DefaultIfEmpty(0).Max()
                })
                .Where(item => item.Confidence >= 0.86)
                .OrderByDescending(item => item.Confidence)
                .ThenByDescending(item => GetPlatformWeight(item.Record, systemKey, aliases))
                .ThenByDescending(item => item.Record.Score)
                .ToArray();

            if (ranked.Length == 0)
            {
                return null;
            }

            return new RatingMatch(ranked[0].Record, ranked[0].Confidence, "Fuzzy");
        }

        private static void AddCandidateKey(HashSet<string> keys, string value)
        {
            string key = NormalizeKey(value);
            if (!string.IsNullOrWhiteSpace(key))
            {
                keys.Add(key);
            }
        }

        private static RatingRecord PickBest(IEnumerable<RatingRecord> records, string systemKey, SystemAliasMap aliases)
        {
            return records
                .OrderByDescending(record => GetPlatformWeight(record, systemKey, aliases))
                .ThenByDescending(record => record.Score)
                .ThenBy(record => record.Title, StringComparer.OrdinalIgnoreCase)
                .First();
        }

        private static double GetPlatformWeight(RatingRecord record, string systemKey, SystemAliasMap aliases)
        {
            string platform = NormalizePlainText(record.Platform);
            if (string.IsNullOrWhiteSpace(platform))
            {
                return 0.5;
            }

            var candidates = new List<string> { systemKey, aliases.Resolve(systemKey), GetDisplayName(systemKey) };
            if (AliasSource.TryGetValue(systemKey, out string[]? aliasList))
            {
                candidates.AddRange(aliasList);
            }

            return candidates
                .Select(NormalizePlainText)
                .Where(candidate => !string.IsNullOrWhiteSpace(candidate))
                .Any(candidate => platform.Equals(candidate, StringComparison.OrdinalIgnoreCase) || platform.Contains(candidate, StringComparison.OrdinalIgnoreCase))
                ? 1.0
                : 0.0;
        }

        private static IEnumerable<string> Tokenize(string key)
        {
            string spaced = Regex.Replace(key, @"([a-z])(\d)", "$1 $2");
            spaced = Regex.Replace(spaced, @"(\d)([a-z])", "$1 $2");
            foreach (string part in Regex.Split(spaced, @"[^a-z0-9]+"))
            {
                if (part.Length >= 3)
                {
                    yield return part;
                }
            }

            if (key.Length >= 5)
            {
                yield return key[..Math.Min(8, key.Length)];
            }
        }

        private static double GetSimilarity(string a, string b)
        {
            string left = Compact(a);
            string right = Compact(b);
            if (left.Length == 0 || right.Length == 0)
            {
                return 0;
            }

            if (left.Equals(right, StringComparison.OrdinalIgnoreCase))
            {
                return 1;
            }

            string shorter = left.Length <= right.Length ? left : right;
            string longer = left.Length > right.Length ? left : right;
            if (shorter.Length >= 6 && longer.Contains(shorter, StringComparison.OrdinalIgnoreCase))
            {
                return Math.Min(0.94, 0.82 + (shorter.Length / (double)longer.Length * 0.12));
            }

            int distance = Levenshtein(left, right);
            int max = Math.Max(left.Length, right.Length);
            return Math.Max(0, 1.0 - (distance / (double)max));
        }

        private static int Levenshtein(string a, string b)
        {
            int[,] matrix = new int[a.Length + 1, b.Length + 1];
            for (int i = 0; i <= a.Length; i++)
            {
                matrix[i, 0] = i;
            }

            for (int j = 0; j <= b.Length; j++)
            {
                matrix[0, j] = j;
            }

            for (int i = 1; i <= a.Length; i++)
            {
                for (int j = 1; j <= b.Length; j++)
                {
                    int cost = a[i - 1] == b[j - 1] ? 0 : 1;
                    matrix[i, j] = Math.Min(
                        Math.Min(matrix[i - 1, j] + 1, matrix[i, j - 1] + 1),
                        matrix[i - 1, j - 1] + cost);
                }
            }

            return matrix[a.Length, b.Length];
        }

        private static void Add(Dictionary<string, List<RatingRecord>> index, string key, RatingRecord record)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return;
            }

            if (!index.TryGetValue(key, out List<RatingRecord>? records))
            {
                records = [];
                index[key] = records;
            }

            records.Add(record);
        }
    }
}
