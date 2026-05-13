using Sifter.Core;
using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace Sifter.App;

public partial class App : System.Windows.Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
        {
            if (args.ExceptionObject is Exception ex)
            {
                WriteCrashLog("AppDomain", ex);
            }
        };

        DispatcherUnhandledException += (_, args) =>
        {
            WriteCrashLog("Dispatcher", args.Exception);
            System.Windows.MessageBox.Show(
                args.Exception.Message,
                "Sifter ran into a problem",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
            args.Handled = true;
        };

        TaskScheduler.UnobservedTaskException += (_, args) =>
        {
            WriteCrashLog("TaskScheduler", args.Exception);
            args.SetObserved();
        };

        base.OnStartup(e);
    }

    private static void WriteCrashLog(string source, Exception exception)
    {
        try
        {
            AppPaths paths = AppPaths.FromEnvironment();
            paths.EnsureBaseDirectories();
            string path = Path.Combine(paths.LogDirectory, $"SifterCrash_{DateTime.Now:yyyyMMdd_HHmmss}.log");
            File.WriteAllText(path, $"Source: {source}{Environment.NewLine}{exception}");
        }
        catch
        {
            // Last-chance logging should never create another crash path.
        }
    }
}
