using Sifter.Core;

namespace Sifter.Core.Tests;

[TestClass]
public sealed class SifterEngineTests
{
    [TestMethod]
    public void ScanLibraryUsesXmlFirstMatchingAndPicksTopGame()
    {
        string root = CreateTempRoot();
        string gamelists = Path.Combine(root, "gamelists");
        string roms = Path.Combine(root, "roms");
        string appData = Path.Combine(root, "appdata");
        string gcGamelist = Path.Combine(gamelists, "gc", "gamelist.xml");
        string gcRomRoot = Path.Combine(roms, "gc");

        Directory.CreateDirectory(Path.GetDirectoryName(gcGamelist)!);
        Directory.CreateDirectory(gcRomRoot);
        File.Copy(FixturePath("gamelists", "gc", "gamelist.xml"), gcGamelist);
        File.WriteAllText(Path.Combine(gcRomRoot, "The Legend of Zelda - Ocarina of Time (USA).z64"), "rom");

        var engine = new SifterEngine(AppPaths.FromEnvironment(appData));
        var settings = new SifterSettings
        {
            GamelistsRoot = gamelists,
            RomsRoot = roms,
            RatingFilePath = FixturePath("metacritic_fixture.jsonl"),
            MinimumScore = 90,
            TopPerSystem = 5
        };

        IReadOnlyList<LibraryGame> games = engine.ScanLibrary(settings);
        LibraryGame zelda = games.Single(game => game.GameName == "The Legend of Zelda: Ocarina of Time");
        LibraryGame missing = games.Single(game => game.GameName == "Missing Game");

        Assert.AreEqual(99, zelda.CriticScore);
        Assert.IsTrue(zelda.Selected);
        Assert.HasCount(1, zelda.SourceFiles);
        Assert.IsEmpty(missing.SourceFiles);
    }

    [TestMethod]
    public void SaveSelectedFavoritesWritesBackupAndFavoriteNode()
    {
        string root = CreateTempRoot();
        string gamelists = Path.Combine(root, "gamelists");
        string roms = Path.Combine(root, "roms");
        string appData = Path.Combine(root, "appdata");
        string gbaGamelist = Path.Combine(gamelists, "gba", "gamelist.xml");
        string gbaRomRoot = Path.Combine(roms, "gba");
        string ratings = Path.Combine(root, "ratings.jsonl");

        Directory.CreateDirectory(Path.GetDirectoryName(gbaGamelist)!);
        Directory.CreateDirectory(gbaRomRoot);
        File.WriteAllText(
            gbaGamelist,
            """
            <gameList>
              <game>
                <path>./Test Game.gba</path>
                <name>Test Game</name>
                <genre>Action</genre>
              </game>
            </gameList>
            """);
        File.WriteAllText(Path.Combine(gbaRomRoot, "Test Game.gba"), "rom");
        File.WriteAllText(ratings, """{"title":"Test Game","metascore":92,"platform":"Game Boy Advance"}""");

        var engine = new SifterEngine(AppPaths.FromEnvironment(appData));
        var settings = new SifterSettings
        {
            GamelistsRoot = gamelists,
            RomsRoot = roms,
            RatingFilePath = ratings,
            MinimumScore = 80,
            TopPerSystem = 1
        };

        IReadOnlyList<LibraryGame> games = engine.ScanLibrary(settings);
        FavoriteResult result = engine.SaveSelectedFavorites(games);

        Assert.AreEqual(1, result.Games);
        Assert.HasCount(1, result.Backups);
        StringAssert.Contains(File.ReadAllText(gbaGamelist), "<favorite>true</favorite>");
    }

    private static string CreateTempRoot()
    {
        string root = Path.Combine(Path.GetTempPath(), "SifterEngineTests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        return root;
    }

    private static string FixturePath(params string[] parts)
    {
        string[] segments = [AppContext.BaseDirectory, "..", "..", "..", "..", "fixtures", .. parts];
        return Path.GetFullPath(Path.Combine(segments));
    }
}
