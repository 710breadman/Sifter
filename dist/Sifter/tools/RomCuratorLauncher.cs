using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Sifter")]
[assembly: AssemblyDescription("Sifter launcher")]
[assembly: AssemblyProduct("Sifter")]
[assembly: AssemblyCompany("710breadman")]
[assembly: AssemblyVersion("0.3.0.0")]
[assembly: AssemblyFileVersion("0.3.0.0")]

internal static class Program
{
    [STAThread]
    private static int Main()
    {
        try
        {
            return LaunchSifter();
        }
        catch (Exception ex)
        {
            ShowError("Sifter could not start.", ex.ToString());
            return 1;
        }
    }

    private static int LaunchSifter()
    {
        string appDir = AppDomain.CurrentDomain.BaseDirectory;
        string scriptPath = Path.Combine(appDir, "Run-RomCurator.ps1");

        if (!File.Exists(scriptPath))
        {
            ShowError(
                "Sifter could not start.",
                "Run-RomCurator.ps1 was not found next to Sifter.exe.\r\n\r\nExpected path:\r\n" + scriptPath);
            return 2;
        }

        string powershellPath = GetWindowsPowerShellPath();
        if (String.IsNullOrEmpty(powershellPath) || !File.Exists(powershellPath))
        {
            powershellPath = FindOnPath("powershell.exe");
        }

        if (String.IsNullOrEmpty(powershellPath))
        {
            ShowError(
                "Sifter could not start.",
                "Windows PowerShell was not found. Sifter needs PowerShell to host the WPF app.");
            return 3;
        }

        string arguments =
            "-NoProfile -ExecutionPolicy Bypass -STA -File " +
            QuoteArgument(scriptPath) +
            " -NoStaRelaunch";

        ProcessStartInfo startInfo = new ProcessStartInfo
        {
            FileName = powershellPath,
            Arguments = arguments,
            WorkingDirectory = appDir,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        Process.Start(startInfo);
        return 0;
    }

    private static string GetWindowsPowerShellPath()
    {
        string systemRoot = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        if (String.IsNullOrEmpty(systemRoot))
        {
            systemRoot = Environment.GetEnvironmentVariable("WINDIR");
        }

        if (String.IsNullOrEmpty(systemRoot))
        {
            return null;
        }

        return Path.Combine(systemRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
    }

    private static string FindOnPath(string fileName)
    {
        string path = Environment.GetEnvironmentVariable("PATH");
        if (String.IsNullOrEmpty(path))
        {
            return null;
        }

        foreach (string rawPart in path.Split(Path.PathSeparator))
        {
            if (String.IsNullOrWhiteSpace(rawPart))
            {
                continue;
            }

            string candidate = Path.Combine(rawPart.Trim(), fileName);
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        return null;
    }

    private static string QuoteArgument(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static void ShowError(string caption, string message)
    {
        MessageBox.Show(message, caption, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
