using Microsoft.Win32;
using Sifter.Core;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using WpfCheckBox = System.Windows.Controls.CheckBox;
using WpfCursors = System.Windows.Input.Cursors;
using WpfMessageBox = System.Windows.MessageBox;
using WpfOpenFileDialog = Microsoft.Win32.OpenFileDialog;
using WpfOpenFolderDialog = Microsoft.Win32.OpenFolderDialog;

namespace Sifter.App;

public partial class MainWindow : Window
{
    private readonly AppPaths appPaths;
    private readonly SifterEngine engine;
    private readonly List<SystemChoice> discoveredSystems = [];
    private bool updatingGenreQuickPick;

    public ObservableCollection<LibraryGame> Games { get; } = [];

    public MainWindow()
    {
        InitializeComponent();

        DataContext = this;
        appPaths = AppPaths.FromEnvironment();
        engine = new SifterEngine(appPaths);

        SetWindowIcon();
        BuildInfoText.Text = $"{SifterAppInfo.Version} | native Windows app | .NET {Environment.Version}";

        PopulateGenres();
        LoadSettingsIntoUi(engine.LoadSettings());
        WireCommands();
        UpdateSummary();
    }

    private void WireCommands()
    {
        BrowseGamelistsButton.Click += (_, _) => BrowseFolderInto(GamelistsRootText, "Choose the folder that contains system gamelist folders");
        BrowseRomsButton.Click += (_, _) => BrowseFolderInto(RomsRootText, "Choose the folder that contains ROM system folders");
        BrowseExportButton.Click += (_, _) => BrowseFolderInto(ExportRootText, "Choose where selected games should be copied");
        BrowseRatingsButton.Click += (_, _) => BrowseRatingsFile();
        UseBundledRatingsButton.Click += (_, _) =>
        {
            RatingsFileText.Text = string.Empty;
            SetStatus("Using the built-in Metacritic rating file.");
        };

        SaveSettingsButton.Click += (_, _) => SaveSettingsFromUi();
        OpenLogsButton.Click += (_, _) => OpenFolder(appPaths.LogDirectory);
        DiscoverSystemsButton.Click += (_, _) => DiscoverSystems();
        SelectAllSystemsButton.Click += (_, _) => SetAllSystems(true);
        SelectNoSystemsButton.Click += (_, _) => SetAllSystems(false);
        FilterPresetCombo.SelectionChanged += (_, _) => ApplyPreset();
        GenreQuickCombo.SelectionChanged += (_, _) => ApplyGenreQuickPick();

        ScanButton.Click += async (_, _) => await RunScanAsync();
        PickTopButton.Click += (_, _) => PickTopGames();
        PreviewCopyButton.Click += async (_, _) => await RunExportAsync(dryRun: true);
        CopyButton.Click += async (_, _) => await RunExportAsync(dryRun: false);
        FavoriteButton.Click += async (_, _) => await RunFavoritesAsync();
        SelectAllGamesButton.Click += (_, _) => SetAllGames(true);
        ClearGameSelectionButton.Click += (_, _) => SetAllGames(false);
    }

    private void PopulateGenres()
    {
        foreach (string genre in SifterEngine.BroadGenres)
        {
            var check = new WpfCheckBox
            {
                Content = genre,
                Tag = genre,
                MinWidth = 142
            };
            check.Checked += (_, _) => MarkCustomGenreChoice();
            check.Unchecked += (_, _) => MarkCustomGenreChoice();
            GenreListPanel.Children.Add(check);
        }
    }

    private void LoadSettingsIntoUi(SifterSettings settings)
    {
        GamelistsRootText.Text = settings.GamelistsRoot;
        RomsRootText.Text = settings.RomsRoot;
        ExportRootText.Text = settings.ExportRoot;
        RatingsFileText.Text = settings.RatingFilePath;
        MinimumScoreText.Text = settings.MinimumScore.ToString();
        TopPerSystemText.Text = settings.TopPerSystem.ToString();
        OverwriteCheck.IsChecked = settings.OverwriteExisting;
        DryRunCheck.IsChecked = settings.DryRun;
        ExcludeDuplicatesCheck.IsChecked = settings.ExcludeDuplicates;

        foreach (WpfCheckBox check in GenreListPanel.Children.OfType<WpfCheckBox>())
        {
            check.IsChecked = settings.ExcludedGenres.Contains((string)check.Tag, StringComparer.OrdinalIgnoreCase);
        }
    }

    private SifterSettings ReadSettingsFromUi()
    {
        return new SifterSettings
        {
            GamelistsRoot = GamelistsRootText.Text.Trim(),
            RomsRoot = RomsRootText.Text.Trim(),
            ExportRoot = ExportRootText.Text.Trim(),
            RatingFilePath = RatingsFileText.Text.Trim(),
            MinimumScore = ReadInt(MinimumScoreText.Text, 75, 0, 100),
            TopPerSystem = ReadInt(TopPerSystemText.Text, 25, 1, 10000),
            OverwriteExisting = OverwriteCheck.IsChecked == true,
            DryRun = DryRunCheck.IsChecked == true,
            ExcludeDuplicates = ExcludeDuplicatesCheck.IsChecked == true,
            SelectedSystems = GetSelectedSystemKeys(),
            ExcludedGenres = GetSelectedGenres()
        };
    }

    private void SaveSettingsFromUi()
    {
        engine.SaveSettings(ReadSettingsFromUi());
        SetStatus("Settings saved.");
    }

    private void DiscoverSystems()
    {
        try
        {
            SifterSettings settings = ReadSettingsFromUi();
            discoveredSystems.Clear();
            discoveredSystems.AddRange(engine.DiscoverSystems(settings, new Progress<string>(AppendLog)));
            RenderSystems(settings);
            engine.SaveSettings(ReadSettingsFromUi());
            AppendLog($"Found {discoveredSystems.Count} system(s).");
            SetStatus($"Found {discoveredSystems.Count} system(s).");
        }
        catch (Exception ex)
        {
            ShowError(ex);
        }
    }

    private async Task RunScanAsync()
    {
        await RunBusyAsync("Scanning library...", () =>
        {
            SifterSettings settings = ReadSettingsFromUi();
            engine.SaveSettings(settings);
            IReadOnlyList<LibraryGame> result = engine.ScanLibrary(settings, new Progress<string>(AppendLog));

            Dispatcher.Invoke(() =>
            {
                Games.Clear();
                foreach (LibraryGame game in result
                    .OrderBy(game => game.SystemName, StringComparer.OrdinalIgnoreCase)
                    .ThenByDescending(game => game.CriticScore ?? -1)
                    .ThenBy(game => game.GameName, StringComparer.OrdinalIgnoreCase))
                {
                    game.PropertyChanged += Game_PropertyChanged;
                    Games.Add(game);
                }

                CandidateGrid.Items.Refresh();
                UpdateSummary();
            });
        });
    }

    private async Task RunExportAsync(bool dryRun)
    {
        if (Games.Count == 0)
        {
            SetStatus("Scan your library first.");
            return;
        }

        await RunBusyAsync(dryRun ? "Previewing copy..." : "Copying selected games...", () =>
        {
            SifterSettings settings = ReadSettingsFromUi();
            ExportResult result = engine.ExportSelected(settings, Games, dryRun, new Progress<string>(AppendLog));
            Dispatcher.Invoke(() =>
            {
                foreach (string message in result.Messages)
                {
                    AppendLog(message);
                }

                SetStatus(dryRun
                    ? $"Preview ready: {result.Files} file(s), {FormatBytes(result.Bytes)}."
                    : $"Copy complete: {result.Files} file(s), {FormatBytes(result.Bytes)}.");
            });
        });
    }

    private async Task RunFavoritesAsync()
    {
        if (Games.Count == 0)
        {
            SetStatus("Scan your library first.");
            return;
        }

        await RunBusyAsync("Saving favorites...", () =>
        {
            FavoriteResult result = engine.SaveSelectedFavorites(Games, new Progress<string>(AppendLog));
            Dispatcher.Invoke(() =>
            {
                foreach (string message in result.Messages)
                {
                    AppendLog(message);
                }

                foreach (string backup in result.Backups)
                {
                    AppendLog($"Backup: {backup}");
                }

                SetStatus($"Favorites updated: {result.Games} game(s).");
            });
        });
    }

    private async Task RunBusyAsync(string status, Action work)
    {
        try
        {
            SetBusy(true);
            SetStatus(status);
            await Task.Run(work);
        }
        catch (Exception ex)
        {
            ShowError(ex);
        }
        finally
        {
            SetBusy(false);
            UpdateSummary();
        }
    }

    private void PickTopGames()
    {
        if (Games.Count == 0)
        {
            SetStatus("Scan your library first.");
            return;
        }

        engine.PickTopGames(Games, ReadSettingsFromUi());
        CandidateGrid.Items.Refresh();
        UpdateSummary();
        SetStatus("Top games picked.");
    }

    private void RenderSystems(SifterSettings settings)
    {
        SystemListPanel.Children.Clear();
        var selected = new HashSet<string>(
            settings.SelectedSystems.Count == 0 ? discoveredSystems.Select(system => system.Key) : settings.SelectedSystems,
            StringComparer.OrdinalIgnoreCase);

        foreach (SystemChoice system in discoveredSystems)
        {
            var check = new WpfCheckBox
            {
                IsChecked = selected.Contains(system.Key),
                Tag = system,
                Content = $"{system.DisplayName} ({system.GameCount}){(system.HasRomFolder ? string.Empty : " - ROM folder missing")}"
            };
            SystemListPanel.Children.Add(check);
        }

        SystemCountText.Text = $"{discoveredSystems.Count} found";
    }

    private void SetAllSystems(bool selected)
    {
        foreach (WpfCheckBox check in SystemListPanel.Children.OfType<WpfCheckBox>())
        {
            check.IsChecked = selected;
        }
    }

    private List<string> GetSelectedSystemKeys()
    {
        return SystemListPanel.Children
            .OfType<WpfCheckBox>()
            .Where(check => check.IsChecked == true)
            .Select(check => ((SystemChoice)check.Tag).Key)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private List<string> GetSelectedGenres()
    {
        return GenreListPanel.Children
            .OfType<WpfCheckBox>()
            .Where(check => check.IsChecked == true)
            .Select(check => (string)check.Tag)
            .ToList();
    }

    private void SetAllGames(bool selected)
    {
        foreach (LibraryGame game in Games)
        {
            game.Selected = selected;
        }

        CandidateGrid.Items.Refresh();
        UpdateSummary();
    }

    private void ApplyPreset()
    {
        switch (FilterPresetCombo.SelectedIndex)
        {
            case 1:
                MinimumScoreText.Text = "85";
                TopPerSystemText.Text = "15";
                ExcludeDuplicatesCheck.IsChecked = true;
                break;
            case 2:
                MinimumScoreText.Text = "80";
                TopPerSystemText.Text = "10";
                ExcludeDuplicatesCheck.IsChecked = true;
                break;
            case 0:
                MinimumScoreText.Text = "75";
                TopPerSystemText.Text = "25";
                ExcludeDuplicatesCheck.IsChecked = true;
                break;
        }
    }

    private void ApplyGenreQuickPick()
    {
        if (updatingGenreQuickPick)
        {
            return;
        }

        if (GenreQuickCombo.SelectedIndex == 3)
        {
            return;
        }

        var selected = GenreQuickCombo.SelectedIndex switch
        {
            1 => new HashSet<string>(["Sports", "Racing"], StringComparer.OrdinalIgnoreCase),
            2 => new HashSet<string>(["Sports", "Racing", "Fighting"], StringComparer.OrdinalIgnoreCase),
            _ => new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        };

        updatingGenreQuickPick = true;
        foreach (WpfCheckBox check in GenreListPanel.Children.OfType<WpfCheckBox>())
        {
            check.IsChecked = selected.Contains((string)check.Tag);
        }
        updatingGenreQuickPick = false;
    }

    private void MarkCustomGenreChoice()
    {
        if (!updatingGenreQuickPick && GenreQuickCombo.SelectedIndex != 3)
        {
            GenreQuickCombo.SelectedIndex = 3;
        }
    }

    private void BrowseFolderInto(System.Windows.Controls.TextBox target, string description)
    {
        var dialog = new WpfOpenFolderDialog
        {
            Title = description,
            InitialDirectory = Directory.Exists(target.Text) ? target.Text : string.Empty
        };

        if (dialog.ShowDialog(this) == true)
        {
            target.Text = dialog.FolderName;
        }
    }

    private void BrowseRatingsFile()
    {
        var dialog = new WpfOpenFileDialog
        {
            Title = "Choose Metacritic JSON or JSONL file",
            Filter = "Rating files (*.json;*.jsonl)|*.json;*.jsonl|All files (*.*)|*.*"
        };

        if (File.Exists(RatingsFileText.Text))
        {
            dialog.InitialDirectory = Path.GetDirectoryName(RatingsFileText.Text);
            dialog.FileName = Path.GetFileName(RatingsFileText.Text);
        }

        if (dialog.ShowDialog(this) == true)
        {
            RatingsFileText.Text = dialog.FileName;
        }
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

    private void SetBusy(bool busy)
    {
        Mouse.OverrideCursor = busy ? WpfCursors.Wait : null;
        ScanButton.IsEnabled = !busy;
        PickTopButton.IsEnabled = !busy;
        PreviewCopyButton.IsEnabled = !busy;
        CopyButton.IsEnabled = !busy;
        FavoriteButton.IsEnabled = !busy;
        DiscoverSystemsButton.IsEnabled = !busy;
    }

    private void UpdateSummary()
    {
        int total = Games.Count;
        int selected = Games.Count(game => game.Selected);
        int copyable = Games.Count(game => game.Selected && game.SourceFiles.Count > 0 && string.IsNullOrWhiteSpace(game.Issues));
        int missing = Games.Count(game => game.SourceFiles.Count == 0);
        long selectedBytes = Games
            .Where(game => game.Selected)
            .SelectMany(game => game.SourceFiles)
            .Where(File.Exists)
            .Sum(file => new FileInfo(file).Length);

        SummaryTitleText.Text = total == 0
            ? "No scan yet"
            : $"{selected} selected from {total} games";

        SummaryDetailText.Text = total == 0
            ? "Discover systems, scan your library, then Sifter will pre-pick a simple top-rated set."
            : $"{copyable} ready to copy, {missing} missing ROM entry/entries, {FormatBytes(selectedBytes)} selected.";
    }

    private void Game_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(LibraryGame.Selected))
        {
            UpdateSummary();
        }
    }

    private void AppendLog(string message)
    {
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(() => AppendLog(message));
            return;
        }

        if (!string.IsNullOrWhiteSpace(LogText.Text))
        {
            LogText.AppendText(Environment.NewLine);
        }

        LogText.AppendText($"[{DateTime.Now:T}] {message}");
        LogText.ScrollToEnd();
        SetStatus(message);
    }

    private void SetStatus(string status)
    {
        StatusText.Text = status;
    }

    private void ShowError(Exception ex)
    {
        AppendLog($"Error: {ex.Message}");
        SetStatus(ex.Message);
        WpfMessageBox.Show(this, ex.Message, "Sifter", MessageBoxButton.OK, MessageBoxImage.Warning);
    }

    private void SetWindowIcon()
    {
        try
        {
            Icon = BitmapFrame.Create(new Uri("pack://application:,,,/Assets/Sifter.ico", UriKind.Absolute));
        }
        catch
        {
            // The executable still carries the icon if the window resource cannot be loaded.
        }
    }

    private static int ReadInt(string text, int fallback, int min, int max)
    {
        if (!int.TryParse(text.Trim(), out int value))
        {
            value = fallback;
        }

        return Math.Clamp(value, min, max);
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double value = bytes;
        int unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }

        return $"{value:0.##} {units[unit]}";
    }

}
