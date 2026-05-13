using Sifter.Core;

namespace Sifter.Core.Tests;

[TestClass]
public sealed class AppPathsTests
{
    [TestMethod]
    public void FromEnvironmentKeepsExistingAppDataLocation()
    {
        AppPaths paths = AppPaths.FromEnvironment(@"C:\Users\Test\AppData\Roaming");

        Assert.AreEqual(@"C:\Users\Test\AppData\Roaming\RomCurator", paths.AppDataRoot);
        Assert.AreEqual(@"C:\Users\Test\AppData\Roaming\RomCurator\cache\library_cache.json", paths.LibraryCacheFile);
        Assert.AreEqual(@"C:\Users\Test\AppData\Roaming\RomCurator\settings.json", paths.SettingsFile);
    }
}
