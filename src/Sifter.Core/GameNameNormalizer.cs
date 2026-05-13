using System.Globalization;
using System.Text.RegularExpressions;

namespace Sifter.Core;

public static partial class GameNameNormalizer
{
    private static readonly HashSet<string> NoiseTokens = new(StringComparer.OrdinalIgnoreCase)
    {
        "usa", "us", "eur", "europe", "jpn", "japan", "world",
        "rev", "demo", "beta", "prototype", "proto",
        "en", "fr", "de", "es", "it", "pt", "multi", "multi2", "multi3", "multi4", "multi5",
        "ps3", "ps2", "ps1", "psx", "xbox", "x360", "switch", "nsw",
        "abstrakt", "duplex", "complex", "venom", "scene", "group"
    };

    public static string NormalizeDisplayName(string? rawName)
    {
        if (string.IsNullOrWhiteSpace(rawName))
        {
            return string.Empty;
        }

        string name = Path.GetFileNameWithoutExtension(rawName.Trim());
        name = BracketedTagRegex().Replace(name, " ");
        name = SeparatorRegex().Replace(name, " ");
        name = KnownCodeRegex().Replace(name, " ");
        name = WhitespaceRegex().Replace(name, " ").Trim();

        if (name.Length == 0)
        {
            return string.Empty;
        }

        var meaningfulTokens = new List<string>();
        foreach (string token in name.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (KnownCodeRegex().IsMatch(token))
            {
                continue;
            }

            if (NoiseTokens.Contains(token))
            {
                if (meaningfulTokens.Count > 0)
                {
                    break;
                }

                continue;
            }

            meaningfulTokens.Add(token);
        }

        string cleaned = meaningfulTokens.Count == 0
            ? name
            : string.Join(' ', meaningfulTokens);

        cleaned = ToTitleCase(cleaned);
        return cleaned.Equals("Sacred 2 Fallen Angel", StringComparison.Ordinal)
            ? "Sacred 2: Fallen Angel"
            : cleaned;
    }

    public static string NormalizeKey(string? rawName)
    {
        string display = NormalizeDisplayName(rawName);
        return KeyNoiseRegex().Replace(display.ToLowerInvariant(), string.Empty);
    }

    private static string ToTitleCase(string value)
    {
        TextInfo textInfo = CultureInfo.InvariantCulture.TextInfo;
        string lowered = value.ToLowerInvariant();
        return textInfo.ToTitleCase(lowered).Replace(" Ii", " II", StringComparison.Ordinal);
    }

    [GeneratedRegex(@"[\(\[\{].*?[\)\]\}]", RegexOptions.Compiled)]
    private static partial Regex BracketedTagRegex();

    [GeneratedRegex(@"[_\.\-]+", RegexOptions.Compiled)]
    private static partial Regex SeparatorRegex();

    [GeneratedRegex(@"\b[A-Z]{4}\d{5}\b", RegexOptions.Compiled | RegexOptions.IgnoreCase)]
    private static partial Regex KnownCodeRegex();

    [GeneratedRegex(@"\s+", RegexOptions.Compiled)]
    private static partial Regex WhitespaceRegex();

    [GeneratedRegex(@"[^a-z0-9]+", RegexOptions.Compiled)]
    private static partial Regex KeyNoiseRegex();
}
