using Sifter.Core;

namespace Sifter.Core.Tests;

[TestClass]
public sealed class GameNameNormalizerTests
{
    [TestMethod]
    [DataRow("Rage_EUR_MULTi4_PS3-ABSTRAKT", "Rage")]
    [DataRow("Sacred_2_Fallen_Angel_BLES00410", "Sacred 2: Fallen Angel")]
    [DataRow("Game.Name.USA.En.Fr.De.SceneGroup", "Game Name")]
    public void NormalizeDisplayNameRemovesReleaseNoise(string rawName, string expected)
    {
        Assert.AreEqual(expected, GameNameNormalizer.NormalizeDisplayName(rawName));
    }

    [TestMethod]
    public void NormalizeKeyReturnsStableComparisonKey()
    {
        Assert.AreEqual("thelegendofzelda", GameNameNormalizer.NormalizeKey("The Legend of Zelda (USA).z64"));
    }
}
