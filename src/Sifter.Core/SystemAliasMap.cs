using System.Text.Json;
using System.Text.RegularExpressions;

namespace Sifter.Core;

public sealed partial class SystemAliasMap
{
    private readonly Dictionary<string, string> aliases;

    private SystemAliasMap(Dictionary<string, string> aliases)
    {
        this.aliases = aliases;
    }

    public static SystemAliasMap FromDictionary(IReadOnlyDictionary<string, string[]> source)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach ((string canonical, IReadOnlyList<string> aliasList) in source)
        {
            map[Normalize(canonical)] = canonical;

            foreach (string alias in aliasList)
            {
                map[Normalize(alias)] = canonical;
            }
        }

        return new SystemAliasMap(map);
    }

    public static SystemAliasMap FromJson(string json)
    {
        var parsed = JsonSerializer.Deserialize<Dictionary<string, string[]>>(json)
            ?? throw new InvalidOperationException("System alias JSON could not be parsed.");

        return FromDictionary(parsed);
    }

    public string Resolve(string system)
    {
        string key = Normalize(system);
        return aliases.TryGetValue(key, out string? canonical)
            ? canonical
            : system;
    }

    public static string Normalize(string value)
    {
        return AliasNoiseRegex().Replace(value.Trim().ToLowerInvariant(), string.Empty);
    }

    [GeneratedRegex(@"[^a-z0-9]+", RegexOptions.Compiled)]
    private static partial Regex AliasNoiseRegex();
}
