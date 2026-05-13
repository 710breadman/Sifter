namespace Sifter.Core;

public sealed record AppPaths(
    string AppDataRoot,
    string CacheDirectory,
    string LogDirectory,
    string SettingsFile,
    string LibraryCacheFile,
    string RatingsFile,
    string SelectionPresetsDirectory)
{
    public static AppPaths FromEnvironment(string? roamingAppData = null)
    {
        string appData = roamingAppData
            ?? Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);

        if (string.IsNullOrWhiteSpace(appData))
        {
            throw new InvalidOperationException("The roaming AppData folder could not be resolved.");
        }

        string root = Path.Combine(appData, SifterAppInfo.LegacyAppDataFolderName);
        string cache = Path.Combine(root, "cache");
        string logs = Path.Combine(root, "logs");

        return new AppPaths(
            root,
            cache,
            logs,
            Path.Combine(root, "settings.json"),
            Path.Combine(cache, "library_cache.json"),
            Path.Combine(cache, "metacritic_game_critic_scores.jsonl"),
            Path.Combine(root, "selection-presets"));
    }

    public void EnsureBaseDirectories()
    {
        Directory.CreateDirectory(AppDataRoot);
        Directory.CreateDirectory(CacheDirectory);
        Directory.CreateDirectory(LogDirectory);
        Directory.CreateDirectory(SelectionPresetsDirectory);
    }
}
