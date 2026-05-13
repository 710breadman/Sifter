using Sifter.Core;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;

namespace Sifter.App;

public partial class MainWindow : Window
{
    private readonly AppPaths appPaths;
    private readonly string? stableScriptPath;

    public MainWindow()
    {
        InitializeComponent();

        appPaths = AppPaths.FromEnvironment();
        stableScriptPath = ResolveStableScriptPath();

        SetWindowIcon();
        PopulateRuntimeFields();
        WireCommands();
    }

    private void PopulateRuntimeFields()
    {
        BuildInfoText.Text = $"{SifterAppInfo.Version} | .NET {Environment.Version} | {Environment.OSVersion.VersionString}";
        AppDataPathText.Text = appPaths.AppDataRoot;
        CachePathText.Text = appPaths.CacheDirectory;
        LogPathText.Text = appPaths.LogDirectory;
        StableScriptPathText.Text = stableScriptPath ?? "Not found";
        LaunchStableButton.IsEnabled = stableScriptPath is not null;
    }

    private void WireCommands()
    {
        LaunchStableButton.Click += (_, _) => LaunchStableSifter();
        OpenAppDataButton.Click += (_, _) => OpenFolder(appPaths.AppDataRoot);
        OpenStableFolderButton.Click += (_, _) =>
        {
            if (stableScriptPath is not null)
            {
                OpenFolder(Path.GetDirectoryName(stableScriptPath)!);
            }
        };
        OpenRepositoryButton.Click += (_, _) => OpenUrl(SifterAppInfo.RepositoryUrl);
    }

    private void LaunchStableSifter()
    {
        if (stableScriptPath is null)
        {
            SetStatus("Stable Sifter script was not found.");
            return;
        }

        string powerShell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows),
            "System32",
            "WindowsPowerShell",
            "v1.0",
            "powershell.exe");

        var startInfo = new ProcessStartInfo
        {
            FileName = powerShell,
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -STA -File \"{stableScriptPath}\" -NoStaRelaunch",
            WorkingDirectory = Path.GetDirectoryName(stableScriptPath)!,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        Process.Start(startInfo);
        SetStatus("Stable Sifter launched.");
    }

    private void OpenFolder(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
    }

    private void OpenUrl(string url)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true
        });
    }

    private void SetStatus(string status)
    {
        StatusText.Text = status;
    }

    private void SetWindowIcon()
    {
        try
        {
            Icon = BitmapFrame.Create(new Uri("pack://application:,,,/Assets/Sifter.ico", UriKind.Absolute));
        }
        catch
        {
            // The EXE still has the embedded icon; this only affects the WPF window chrome.
        }
    }

    private static string? ResolveStableScriptPath()
    {
        string baseDirectory = AppContext.BaseDirectory;
        string publishedScript = Path.Combine(baseDirectory, "Stable", "Run-RomCurator.ps1");
        if (File.Exists(publishedScript))
        {
            return publishedScript;
        }

        DirectoryInfo? directory = new(baseDirectory);
        while (directory is not null)
        {
            string candidate = Path.Combine(directory.FullName, "Run-RomCurator.ps1");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        return null;
    }
}
