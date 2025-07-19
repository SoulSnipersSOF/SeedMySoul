# CreateTasks.ps1 - RESTORED WORKING VERSION
param()

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Find Steam installation
$SteamPath = $null
$SearchPaths = @(
    "Program Files (x86)\Steam\steam.exe",
    "Steam\steam.exe", 
    "Program Files\Steam\steam.exe"
)

foreach ($drive in [char[]]([char]'C'..[char]'Z')) {
    foreach ($path in $SearchPaths) {
        $fullPath = "${drive}:\$path"
        if (Test-Path $fullPath) {
            $SteamPath = $fullPath
            break
        }
    }
    if ($SteamPath) { break }
}

if (-not $SteamPath) {
    Write-Host "Steam not found on any drive. Please install Steam or check the path."
    exit 1
}

Write-Host "Steam found at: $SteamPath"

# Use proper timezone conversion based on the PowerShell blog approach
try {
    # Get Eastern Time zone
    $easternTZ = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
    
    # Create 7:00 AM Eastern time for today with proper DateTime kind
    $todayDate = (Get-Date).Date
    $easternTime = [DateTime]::SpecifyKind($todayDate.AddHours(7), [DateTimeKind]::Unspecified)
    
    # Convert to UTC first
    $easternTimeUtc = [System.TimeZoneInfo]::ConvertTimeToUtc($easternTime, $easternTZ)
    
    # Convert UTC to local time
    $localTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($easternTimeUtc, [System.TimeZoneInfo]::Local)
    
    $taskTime1 = $localTime.ToString("HH:mm")
    $taskTime2 = $localTime.AddMinutes(1).ToString("HH:mm")
    
    Write-Host "=== TIMEZONE CONVERSION ==="
    Write-Host "Eastern Time target: $($easternTime.ToString('HH:mm'))"
    Write-Host "UTC equivalent: $($easternTimeUtc.ToString('HH:mm'))"
    Write-Host "Local time equivalent: $taskTime1"
    Write-Host "Tasks will run at: $taskTime1 and $taskTime2"
    Write-Host "=== END CONVERSION ==="
}
catch {
    Write-Host "Timezone conversion failed: $_"
    Write-Host "Falling back to 6:00 AM local time for CST users"
    $taskTime1 = "06:00"
    $taskTime2 = "06:01"
}

try {
    Write-Host "=== CREATING TASK 1 WITH CUSTOM CONDITIONS ==="
    
    # Create XML for Task 1 with specific condition settings
    $task1XML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2025-01-01T$($taskTime1):00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>true</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$SteamPath</Command>
      <Arguments>-applaunch 686810</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    # Save XML to temp file
    $xmlPath1 = "$ScriptDir\task1.xml"
    $task1XML | Out-File -FilePath $xmlPath1 -Encoding Unicode
    
    # Create task using XML
    $cmd1 = "schtasks /Create /TN `"SeedMySoul_LaunchHLL`" /XML `"$xmlPath1`" /F"
    Write-Host "Command: $cmd1"
    $result1 = cmd /c $cmd1 2>&1
    Write-Host "Result: $result1"
    
    # Clean up XML file
    Remove-Item $xmlPath1 -ErrorAction SilentlyContinue
    
    if ($result1 -like "*SUCCESS*") {
        Write-Host "Task 1 created successfully for $taskTime1 with custom conditions."
    } else {
        Write-Host "ERROR: Task 1 creation failed: $result1"
        exit 1
    }
    
    Write-Host "=== CREATING TASK 2 WITH CUSTOM CONDITIONS ==="
    
    # Create XML for Task 2 with specific condition settings
    $task2XML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2025-01-01T$($taskTime2):00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>true</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$ScriptDir\seedsoul.exe</Command>
      <Arguments>auto</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    # Save XML to temp file
    $xmlPath2 = "$ScriptDir\task2.xml"
    $task2XML | Out-File -FilePath $xmlPath2 -Encoding Unicode
    
    # Create task using XML
    $cmd2 = "schtasks /Create /TN `"SeedMySoul_RunSeeder`" /XML `"$xmlPath2`" /F"
    Write-Host "Command: $cmd2"
    $result2 = cmd /c $cmd2 2>&1
    Write-Host "Result: $result2"
    
    # Clean up XML file
    Remove-Item $xmlPath2 -ErrorAction SilentlyContinue
    
    if ($result2 -like "*SUCCESS*") {
        Write-Host "Task 2 created successfully for $taskTime2 with custom conditions."
    } else {
        Write-Host "ERROR: Task 2 creation failed: $result2"
        exit 1
    }
    
    Write-Host "=== ALL TASKS COMPLETED ==="
    Write-Host "Both tasks created successfully with custom condition settings:"
    Write-Host "- Wake computer to run task: ENABLED"
    Write-Host "- All other conditions: DISABLED"
    Write-Host "- Times: $taskTime1 and $taskTime2 (7:00 AM Eastern equivalent)"
}
catch {
    Write-Host "Error creating tasks: $_"
    exit 1
}