using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;
using Newtonsoft.Json;

namespace SEEDMYSOUL
{
    public partial class Form1 : Form
    {
        /* ??????????????????????????????????????????????????????????????????????????? fields */
        private static readonly HttpClient http = new();

        /* log-rotation (keep 7 most recent runs) */
        private readonly string logDir =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                         "SeedMySoulLogs");
        private readonly string currentLogPath;

        private readonly bool autoStart;

        // day-state flags
        private bool server1Full = false;
        private bool server2Full = false;

        // prevent multiple AutoHotkey calls
        private bool isJoiningServer = false;
        private DateTime lastJoinAttempt = DateTime.MinValue;

        /* keep PC awake */
        [DllImport("kernel32.dll")]
        private static extern uint SetThreadExecutionState(uint esFlags);
        private const uint ES_CONTINUOUS = 0x80000000,
                            ES_SYSTEM_REQUIRED = 0x1,
                            ES_DISPLAY_REQUIRED = 0x2;

        /* ??????????????????????????????????????????????????????????????????????????? ctor */
        public Form1(bool auto = false)
        {
            InitializeComponent();
            seedSoulButton.Click += seedSoulButton_Click;
            autoStart = auto;

            // prevent sleep / monitor-off while running
            SetThreadExecutionState(ES_CONTINUOUS |
                                    ES_SYSTEM_REQUIRED |
                                    ES_DISPLAY_REQUIRED);

            currentLogPath = CreateNewLogAndPurgeOld();
        }

        protected override async void OnShown(EventArgs e)
        {
            base.OnShown(e);
            if (autoStart)
            {
                WindowState = FormWindowState.Minimized;
                seedSoulButton.Enabled = false;
                await MonitorLoopAsync();
                Close();
            }
        }

        private async void seedSoulButton_Click(object? s, EventArgs e)
        {
            seedSoulButton.Enabled = false;
            await MonitorLoopAsync();
            seedSoulButton.Enabled = true;
        }

        /* ??????????????????????????????????????????????????????????????????????????? polling loop with day-state */
        private async Task MonitorLoopAsync()
        {
            while (!server2Full)
            {
                if (!server1Full)
                {
                    int pop1 = await GetPopAsync("14968811");
                    Log($"Server 1 = {pop1}");

                    if (pop1 >= 80)
                    {
                        server1Full = true;
                        Log("Server 1 hit 80 ? stop tracking it for today.");
                        continue;                             // immediately check Server 2
                    }

                    if (pop1 < 80)
                    {
                        Log("Server 1 population below 80, attempting to join...");
                        await LaunchHLLAndJoinAsync(
                            "SOULSNIPER'S SOF | NEW PLAYERS WELCOME", pop1);
                    }
                }
                else        // now only watching Server 2
                {
                    int pop2 = await GetPopAsync("33644491");
                    Log($"Server 2 = {pop2}");

                    if (pop2 >= 80)
                    {
                        server2Full = true;
                        Log("Server 2 hit 80 ? done for the day.");
                        break;
                    }

                    Log("Server 1 full; Server 2 below 80 ? attempting to join Server 2");
                    CloseHLL();
                    await LaunchHLLAndJoinAsync(
                        "SOULSNIPER'S SOF 2 | NEW PLAYERS WELCOME", pop2);
                }

                Log("Waiting 5 minutes …");
                await Task.Delay(TimeSpan.FromMinutes(5));
            }

            Log("Exiting – daily job complete.");
        }

        /* ??????????????????????????????????????????????????????????????????????????? BattleMetrics helper */
        private async Task<int> GetPopAsync(string id)
        {
            try
            {
                string json = await http.GetStringAsync(
                    $"https://api.battlemetrics.com/servers/{id}");
                dynamic d = JsonConvert.DeserializeObject(json);
                return (int?)d?.data?.attributes?.players ?? 0;
            }
            catch (Exception ex)
            {
                Log($"API error ({id}): {ex.Message}");
                return 0;
            }
        }

        /* ??????????????????????????????????????????????????????????????????????????? HLL / AutoHotkey */
        private async Task LaunchHLLAndJoinAsync(string server, int pop)
        {
            // Prevent multiple rapid calls
            if (isJoiningServer)
            {
                Log("Already attempting to join a server, skipping this attempt...");
                return;
            }

            // Don't try again if we just attempted recently (within 15 minutes)
            if (DateTime.Now.Subtract(lastJoinAttempt).TotalMinutes < 15)
            {
                Log($"Recent join attempt detected ({DateTime.Now.Subtract(lastJoinAttempt).TotalMinutes:F1} min ago), waiting before trying again...");
                return;
            }

            isJoiningServer = true;
            lastJoinAttempt = DateTime.Now;

            try
            {
                // Clean up any old lockfiles before attempting
                CleanupLockfile();

                if (!IsRunning("HLL"))
                    await LaunchHLLAsync();

                string ahkExe = Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                                             "AutoHotkey", "seedsoul.exe");
                if (!File.Exists(ahkExe))
                {
                    Log("seedsoul.exe missing at: " + ahkExe);
                    return;
                }

                Log($"Running AHK ? \"{server}\"  {pop}");
                var psi = new ProcessStartInfo
                {
                    FileName = ahkExe,
                    Arguments = $"\"{server}\" \"{pop}\"",
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Normal
                };

                var process = Process.Start(psi);
                if (process != null)
                {
                    // Wait for AutoHotkey script to complete, but with a timeout
                    var completedWithinTimeout = await WaitForProcessWithTimeoutAsync(process, TimeSpan.FromMinutes(10));

                    if (completedWithinTimeout)
                    {
                        Log($"AutoHotkey script completed with exit code: {process.ExitCode}");
                    }
                    else
                    {
                        Log("AutoHotkey script timed out after 10 minutes, terminating...");
                        try { process.Kill(); } catch { }
                    }
                }
            }
            catch (Exception ex)
            {
                Log($"Error in LaunchHLLAndJoinAsync: {ex.Message}");
            }
            finally
            {
                isJoiningServer = false;
            }
        }

        private async Task<bool> WaitForProcessWithTimeoutAsync(Process process, TimeSpan timeout)
        {
            var tcs = new TaskCompletionSource<bool>();

            process.EnableRaisingEvents = true;
            process.Exited += (sender, args) => tcs.TrySetResult(true);

            if (process.HasExited)
            {
                return true;
            }

            var timeoutTask = Task.Delay(timeout);
            var completedTask = await Task.WhenAny(tcs.Task, timeoutTask);

            return completedTask == tcs.Task;
        }

        private void CleanupLockfile()
        {
            string lockfile = Path.Combine(Path.GetTempPath(), "SeedMySoul.lock");
            if (File.Exists(lockfile))
            {
                try
                {
                    File.Delete(lockfile);
                    Log("Cleaned up old AutoHotkey lockfile");
                }
                catch (Exception ex)
                {
                    Log($"Failed to cleanup lockfile: {ex.Message}");
                }
            }
        }

        private async Task LaunchHLLAsync()
        {
            const string steam = @"C:\Program Files (x86)\Steam\steam.exe";
            if (!File.Exists(steam)) { Log("Steam.exe not found"); return; }

            Log("Starting HLL …");
            Process.Start(steam, "-applaunch 686810");
            await Task.Delay(60_000);
        }

        /* ??????????????????????????????????????????????????????????????????????????? utils */
        private static bool IsRunning(string name) =>
            Process.GetProcessesByName(name).Length > 0;

        private static void CloseHLL()
        {
            foreach (var p in Process.GetProcessesByName("HLL"))
                try { p.Kill(); } catch { }
        }

        /* ??????????????????????????????????????????????????????????????????????????? logging with rotation */
        private string CreateNewLogAndPurgeOld()
        {
            Directory.CreateDirectory(logDir);

            string newPath = Path.Combine(
                logDir,
                $"ServerLog_{DateTime.Now:yyyyMMdd_HHmmss}.txt");

            var logFiles = new DirectoryInfo(logDir)
                           .GetFiles("ServerLog_*.txt")
                           .OrderByDescending(f => f.CreationTimeUtc)
                           .ToList();

            foreach (var file in logFiles.Skip(7))
                try { file.Delete(); } catch { }

            return newPath;
        }

        private void Log(string msg)
        {
            string line = $"{DateTime.Now:HH:mm:ss}  {msg}";
            File.AppendAllText(currentLogPath, line + Environment.NewLine);
            textBox1.AppendText(line + Environment.NewLine);
        }
    }
}