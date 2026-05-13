using Sifter.Core;

namespace Sifter.Core.Tests;

[TestClass]
public sealed class SystemAliasMapTests
{
    [TestMethod]
    public void ResolveMatchesCanonicalAndAliases()
    {
        const string json = """
        {
          "gc": ["gamecube", "ngc", "nintendo gamecube"],
          "psx": ["ps1", "playstation", "playstation 1"]
        }
        """;

        SystemAliasMap aliases = SystemAliasMap.FromJson(json);

        Assert.AreEqual("gc", aliases.Resolve("Nintendo GameCube"));
        Assert.AreEqual("psx", aliases.Resolve("PlayStation 1"));
        Assert.AreEqual("dreamcast", aliases.Resolve("dreamcast"));
    }
}
