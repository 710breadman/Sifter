using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace Sifter.Core;

public sealed class SifterSettings
{
    public string GamelistsRoot { get; set; } = string.Empty;
    public string RomsRoot { get; set; } = string.Empty;
    public string ExportRoot { get; set; } = string.Empty;
    public string RatingFilePath { get; set; } = string.Empty;
    public int TopPerSystem { get; set; } = 25;
    public int MinimumScore { get; set; } = 75;
    public bool OverwriteExisting { get; set; }
    public bool DryRun { get; set; } = true;
    public bool ExcludeDuplicates { get; set; } = true;
    public List<string> SelectedSystems { get; set; } = [];
    public List<string> ExcludedGenres { get; set; } = [];
}

public sealed record SystemChoice(
    string Key,
    string DisplayName,
    string GamelistPath,
    string RomRoot,
    int GameCount,
    bool HasRomFolder);

public sealed class LibraryGame : INotifyPropertyChanged
{
    private bool selected;

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool Selected
    {
        get => selected;
        set
        {
            if (selected == value)
            {
                return;
            }

            selected = value;
            OnPropertyChanged();
        }
    }

    public string SystemKey { get; init; } = string.Empty;
    public string SystemName { get; init; } = string.Empty;
    public string GameName { get; init; } = string.Empty;
    public string GamelistPath { get; init; } = string.Empty;
    public string XmlName { get; init; } = string.Empty;
    public string XmlPathText { get; init; } = string.Empty;
    public string RomSystemRoot { get; init; } = string.Empty;
    public string RelativePath { get; init; } = string.Empty;
    public string RomPath { get; init; } = string.Empty;
    public string Genre { get; init; } = string.Empty;
    public string Favorite { get; init; } = string.Empty;
    public string RatingTitle { get; init; } = string.Empty;
    public string RatingPlatform { get; init; } = string.Empty;
    public string RatingGenres { get; init; } = string.Empty;
    public double? CriticScore { get; init; }
    public double MatchConfidence { get; init; }
    public string MatchMethod { get; init; } = string.Empty;
    public string Issues { get; init; } = string.Empty;
    public IReadOnlyList<string> SourceFiles { get; init; } = [];

    public string ScoreText => CriticScore.HasValue
        ? Math.Round(CriticScore.Value).ToString(System.Globalization.CultureInfo.InvariantCulture)
        : "-";

    public string ConfidenceText => MatchConfidence > 0
        ? MatchConfidence.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)
        : "-";

    public string StatusText
    {
        get
        {
            if (!string.IsNullOrWhiteSpace(Issues))
            {
                return Issues;
            }

            if (SourceFiles.Count == 0)
            {
                return "Missing ROM";
            }

            if (!CriticScore.HasValue)
            {
                return "No rating";
            }

            return Selected ? "Picked" : "Available";
        }
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        if (propertyName == nameof(Selected))
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(StatusText)));
        }
    }
}

public sealed record ExportResult(
    bool DryRun,
    int Games,
    int Files,
    int Skipped,
    int Errors,
    long Bytes,
    string ManifestPath,
    IReadOnlyList<string> Messages);

public sealed record FavoriteResult(
    int Systems,
    int Games,
    int AlreadyFavorite,
    int Errors,
    IReadOnlyList<string> Backups,
    IReadOnlyList<string> Messages);
