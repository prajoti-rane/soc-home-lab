<#
.SYNOPSIS
    Atomic Red Team detection validation runner for SOC Home Lab.

.DESCRIPTION
    Runs the Atomic Red Team tests corresponding to each of our 8 Wazuh
    detection rules (100001-100019), logs results, and prints correlation
    instructions for Kibana.

    ╔══════════════════════════════════════════════════════════════════╗
    ║  FOR AUTHORIZED HOME LAB USE ONLY                               ║
    ║  Run ONLY on victim-windows VM (192.168.64.20) in the UTM lab.  ║
    ║  Each test generates real attacker-technique artifacts locally.  ║
    ╚══════════════════════════════════════════════════════════════════╝

.PARAMETER OutputPath
    Path to save the results log. Default: C:\Temp\art-results.txt

.PARAMETER TechniquesOnly
    Comma-separated list of technique IDs to run (e.g., "T1003.001,T1059.001").
    Default: runs all 7 mapped techniques.

.PARAMETER SkipCleanup
    If set, does not run -Cleanup after each test (useful for evidence capture).

.PARAMETER DryRun
    Show what would be executed without actually running tests.

.EXAMPLE
    # Run all tests with cleanup
    .\runner.ps1

.EXAMPLE
    # Run only credential dumping and PowerShell tests
    .\runner.ps1 -TechniquesOnly "T1003.001,T1059.001"

.EXAMPLE
    # Preview without executing
    .\runner.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "C:\Temp\art-results.txt",
    [string]$TechniquesOnly = "",
    [switch]$SkipCleanup,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ─── Safety Banner ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  WARNING: FOR AUTHORIZED HOME LAB USE ONLY                      ║" -ForegroundColor Red
Write-Host "║  These tests simulate real attack techniques on this machine.    ║" -ForegroundColor Red
Write-Host "║  Run ONLY on victim-windows VM (192.168.64.20).                  ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] No tests will be executed. Showing test plan only." -ForegroundColor Yellow
    Write-Host ""
}

# ─── Test Definitions ─────────────────────────────────────────────────────────
# Each entry maps one of our Wazuh rules to its ART test.
$tests = @(
    @{
        WazuhRule   = "100001-100002"
        Technique   = "T1110.001"
        TestNumber  = 1
        Name        = "Brute Force SSH Credentials"
        Description = "Simulates SSH password spraying. Triggers Linux sshd failed-login events; requires Kali-side hydra run. This rule fires on the MANAGER (Linux) side, not the Windows victim."
        Severity    = "High (level 10)"
        NeedsAdmin  = $false
        SkipOnVM    = $true   # SSH brute-force runs from Kali, not Windows
        SkipReason  = "SSH brute-force runs from kali-attacker (192.168.64.30), not this Windows host. See scenario 03-lateral-movement.md."
    },
    @{
        WazuhRule   = "100003-100004"
        Technique   = "T1110.001"
        TestNumber  = 9
        Name        = "Password Brute Force via Kerbrute"
        Description = "Simulates RDP/Windows account brute-force generating EventID 4625 entries."
        Severity    = "High (level 10)"
        NeedsAdmin  = $false
        SkipOnVM    = $false
        SkipReason  = ""
    },
    @{
        WazuhRule   = "100005"
        Technique   = "T1003.001"
        TestNumber  = 1
        Name        = "Dump LSASS Memory using ProcDump"
        Description = "Uses procdump64.exe to create a memory dump of lsass.exe. Triggers Sysmon EID 10 → Wazuh rule 100005 (level 14)."
        Severity    = "Critical (level 14)"
        NeedsAdmin  = $true
        SkipOnVM    = $false
        SkipReason  = ""
    },
    @{
        WazuhRule   = "100006-100008"
        Technique   = "T1059.001"
        TestNumber  = 1
        Name        = "PowerShell Encoded Command Execution"
        Description = "Runs powershell.exe with -EncodedCommand flag. Triggers Sysmon EID 1 → Wazuh rule 100007 (level 12)."
        Severity    = "High (level 12)"
        NeedsAdmin  = $false
        SkipOnVM    = $false
        SkipReason  = ""
    },
    @{
        WazuhRule   = "100009-100011"
        Technique   = "T1071.001"
        TestNumber  = 1
        Name        = "Malicious User Agents via Web Request"
        Description = "Makes outbound HTTP requests with known-malicious user-agent strings. Triggers Sysmon EID 3 from a scripting engine. Note: rule 100010 requires 10 connections in 5 min."
        Severity    = "Medium → High"
        NeedsAdmin  = $false
        SkipOnVM    = $false
        SkipReason  = ""
    },
    @{
        WazuhRule   = "100012-100014"
        Technique   = "T1021.002"
        TestNumber  = 2
        Name        = "PsExec Commands (Remote Service)"
        Description = "Installs PSEXESVC service on the local host via PsExec. Triggers Windows EventID 7045 → Wazuh rule 100012 (level 10)."
        Severity    = "High (level 10)"
        NeedsAdmin  = $true
        SkipOnVM    = $false
        SkipReason  = ""
    },
    @{
        WazuhRule   = "100015-100016"
        Technique   = "T1562.001"
        TestNumber  = 1
        Name        = "Disable Windows Defender AV"
        Description = "Adds a Defender exclusion path via Add-MpPreference. Triggers Sysmon EID 13 (registry) → Wazuh rule 100015 (level 14). CLEANUP IS MANDATORY."
        Severity    = "Critical (level 14)"
        NeedsAdmin  = $true
        SkipOnVM    = $false
        SkipReason  = ""
    },
    @{
        WazuhRule   = "100017-100019"
        Technique   = "T1053.005"
        TestNumber  = 1
        Name        = "Scheduled Task Startup Script"
        Description = "Creates a scheduled task via schtasks.exe with a PowerShell action. Triggers Sysmon EID 1 → Wazuh rule 100018 (level 12)."
        Severity    = "High (level 12)"
        NeedsAdmin  = $false
        SkipOnVM    = $false
        SkipReason  = ""
    }
)

# ─── Filter by TechniquesOnly if specified ────────────────────────────────────
if ($TechniquesOnly -ne "") {
    $filter = $TechniquesOnly -split ","
    $tests = $tests | Where-Object { $filter -contains $_.Technique }
    if ($tests.Count -eq 0) {
        Write-Host "No tests matched TechniquesOnly filter: $TechniquesOnly" -ForegroundColor Red
        exit 1
    }
}

# ─── Setup ────────────────────────────────────────────────────────────────────
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$startTime = [System.DateTime]::UtcNow
$runId     = $startTime.ToString("yyyyMMdd-HHmmss")

$log = [System.Text.StringBuilder]::new()
$null = $log.AppendLine("# ART Detection Validation Run — $runId")
$null = $log.AppendLine("# Started: $($startTime.ToString('yyyy-MM-ddTHH:mm:ssZ')) UTC")
$null = $log.AppendLine("# Host: $env:COMPUTERNAME")
$null = $log.AppendLine("# FOR AUTHORIZED HOME LAB USE ONLY")
$null = $log.AppendLine("")

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $null = $log.AppendLine($Message)
}

# ─── Prerequisite: Verify ART Module ──────────────────────────────────────────
Write-Log "─────────────────────────────────────────────────────" "Cyan"
Write-Log "Checking Invoke-AtomicRedTeam module..." "Cyan"

if (-not (Get-Module -ListAvailable -Name invoke-atomicredteam)) {
    Write-Log "[ERROR] invoke-atomicredteam module not found." "Red"
    Write-Log "Install it first:" "Yellow"
    Write-Log "  IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1')" "Yellow"
    Write-Log "  Install-AtomicRedTeam -getAtomics -Force" "Yellow"
    exit 1
}

Import-Module invoke-atomicredteam -Force
Write-Log "[OK] invoke-atomicredteam module loaded" "Green"

# ─── Check Admin for Tests That Require It ────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
Write-Log "Running as Administrator: $isAdmin" "Cyan"
Write-Log ""

# ─── Kibana Correlation Hint ──────────────────────────────────────────────────
$kibanaFrom = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-Log "╔══════════════════════════════════════════════════════╗" "Blue"
Write-Log "║  Kibana correlation timestamp                        ║" "Blue"
Write-Log "║  Filter from: $kibanaFrom       ║" "Blue"
Write-Log "║  URL: http://192.168.64.10:5601                      ║" "Blue"
Write-Log "║  Query: rule.id:[100001 TO 100019]                   ║" "Blue"
Write-Log "╚══════════════════════════════════════════════════════╝" "Blue"
Write-Log ""

# ─── Test Execution Loop ──────────────────────────────────────────────────────
$passCount = 0
$failCount = 0
$skipCount = 0

foreach ($test in $tests) {
    Write-Log "─────────────────────────────────────────────────────" "Cyan"
    Write-Log "Rule:      $($test.WazuhRule)" "White"
    Write-Log "Technique: $($test.Technique) (Test #$($test.TestNumber))" "White"
    Write-Log "Name:      $($test.Name)" "White"
    Write-Log "Severity:  $($test.Severity)" "White"
    Write-Log "Time:      $([System.DateTime]::UtcNow.ToString('HH:mm:ss')) UTC" "Gray"

    # Skip tests that must run from a different host
    if ($test.SkipOnVM) {
        Write-Log "[SKIP] $($test.SkipReason)" "Yellow"
        $skipCount++
        $null = $log.AppendLine("RESULT: SKIPPED — $($test.SkipReason)")
        Start-Sleep -Seconds 1
        continue
    }

    # Skip admin-required tests if not running as admin
    if ($test.NeedsAdmin -and -not $isAdmin) {
        Write-Log "[SKIP] Requires Administrator — re-run PowerShell as Admin" "Yellow"
        $skipCount++
        $null = $log.AppendLine("RESULT: SKIPPED — requires admin rights")
        continue
    }

    if ($DryRun) {
        Write-Log "[DRY RUN] Would execute: Invoke-AtomicTest $($test.Technique) -TestNumbers $($test.TestNumber)" "Yellow"
        continue
    }

    # Get prerequisites
    Write-Log "Getting prerequisites..." "Gray"
    try {
        Invoke-AtomicTest $test.Technique -TestNumbers $test.TestNumber -GetPrereqs 2>&1 | Out-Null
    }
    catch {
        Write-Log "[WARN] Prereq step error (may be OK): $_" "Yellow"
    }

    # Execute the test
    Write-Log "Executing test..." "White"
    $testStart = [System.DateTime]::UtcNow
    try {
        Invoke-AtomicTest $test.Technique -TestNumbers $test.TestNumber 2>&1
        Write-Log "[OK] Test completed at $([System.DateTime]::UtcNow.ToString('HH:mm:ss')) UTC" "Green"
        $null = $log.AppendLine("RESULT: EXECUTED at $testStart UTC")
        $passCount++
    }
    catch {
        Write-Log "[FAIL] Test threw an error: $_" "Red"
        $null = $log.AppendLine("RESULT: ERROR — $_")
        $failCount++
    }

    # Wait for Wazuh to process the event before cleanup
    Write-Log "Waiting 30s for Wazuh/Kibana to process events..." "Gray"
    Start-Sleep -Seconds 30

    # Cleanup
    if (-not $SkipCleanup) {
        Write-Log "Running cleanup..." "Gray"
        try {
            Invoke-AtomicTest $test.Technique -TestNumbers $test.TestNumber -Cleanup 2>&1 | Out-Null
            Write-Log "[OK] Cleanup complete" "Green"
        }
        catch {
            Write-Log "[WARN] Cleanup error (manual cleanup may be needed): $_" "Yellow"
        }

        # Extra cleanup for Defender test — always re-enable
        if ($test.Technique -eq "T1562.001") {
            Write-Log "Re-enabling Windows Defender Real-Time Protection..." "Yellow"
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
            $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($status.RealTimeProtectionEnabled) {
                Write-Log "[OK] Defender Real-Time Protection is ENABLED" "Green"
            } else {
                Write-Log "[WARN] Defender may still be disabled — enable manually in Windows Security" "Red"
            }
        }
    } else {
        Write-Log "[SkipCleanup] Skipping cleanup — remember to clean up manually" "Yellow"
    }

    Write-Log ""
}

# ─── Summary ──────────────────────────────────────────────────────────────────
$endTime = [System.DateTime]::UtcNow
$duration = $endTime - $startTime

Write-Log "═════════════════════════════════════════════════════" "Cyan"
Write-Log "  ART Run Complete — $runId" "Cyan"
Write-Log "  Duration:  $($duration.ToString('hh\:mm\:ss'))" "Cyan"
Write-Log "  Executed:  $passCount tests" "Green"
Write-Log "  Failed:    $failCount tests" $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Log "  Skipped:   $skipCount tests" "Yellow"
Write-Log "═════════════════════════════════════════════════════" "Cyan"
Write-Log ""
Write-Log "Kibana: http://192.168.64.10:5601" "Blue"
Write-Log "Query:  rule.id:[100001 TO 100019] AND @timestamp:[$kibanaFrom TO *]" "Blue"
Write-Log ""

# Write log file
$null = $log.AppendLine("")
$null = $log.AppendLine("# Run ended: $($endTime.ToString('yyyy-MM-ddTHH:mm:ssZ')) UTC")
$null = $log.AppendLine("# Duration: $($duration.ToString('hh\:mm\:ss'))")
$log.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Log "Results log: $OutputPath" "Gray"
