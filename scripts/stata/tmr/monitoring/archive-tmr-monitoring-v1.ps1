<#
.SYNOPSIS
Preview or archive superseded SHG TMR monitoring files.
.DESCRIPTION
Default: read-only preview. -Apply moves an explicit allowlist to a unique
archive subfolder; no files are deleted. Requires the new weekly workflow.
Run tmr-00-weekly-run-v1.do successfully before applying the archive.
-IncludeLegacyRunner also archives run-reports-legacy.do; use only if retired.
Compatible with Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$Apply,
    [switch]$IncludeLegacyRunner
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Explicit SHG location; independent of the PowerShell working directory.
$monitoringRoot = 'C:\yoshimi-hot\output\analyse-sth\sh003-diabetes-registry\info-hub\scripts\stata\tmr\monitoring'
if (-not (Test-Path -LiteralPath $monitoringRoot -PathType Container)) {
    throw "SHG monitoring folder not found: $monitoringRoot"
}
$required = @(
    'tmr-00-weekly-run-v1.do',
    'tmr-01-redcap-extract.do',
    'tmr-02-prepare-data.do',
    'tmr-03-dq-report-v2.do',
    'tmr-run-monitoring-v4.do',
    'tmr-visit-map-audit-v3.do',
    'tmr-02-prepare-data-v3.do',
    'tmr-04-monitor-report-v7.do',
    'tmr-04-monitor-report-v7-noname.do',
    'config\tmr-visit-map.csv'
)
$archiveNames = @(
    'tmr-00-weekly-run.do',
    'tmr-02-prepare-data-v2.do',
    'tmr-03-dq-report.do',
    'tmr-04-monitor-report.do',
    'tmr-04-monitor-report-v2.do',
    'tmr-04-monitor-report-v2-noname.do',
    'tmr-04-monitor-report-v3.do',
    'tmr-04-monitor-report-v3-noname.do',
    'tmr-04-monitor-report-v4.do',
    'tmr-04-monitor-report-v4-noname.do',
    'tmr-04-monitor-report-v5.do',
    'tmr-04-monitor-report-v5-noname.do',
    'tmr-04-monitor-report-v6.do',
    'tmr-04-monitor-report-v6-noname.do',
    'tmr-run-monitoring-v1.do',
    'tmr-run-monitoring-v2.do',
    'tmr-run-monitoring-v3.do',
    'tmr-visit-map-audit-v1.do',
    'tmr-visit-map-audit-v2.do',
    'README-tmr-monitoring-v4.md',
    'testing'
)
if ($IncludeLegacyRunner) { $archiveNames += 'run-reports-legacy.do' }

# Guard against accidentally putting an active dependency on the allowlist.
$overlap = @($archiveNames | Where-Object { $required -contains $_ })
if ($overlap.Count -gt 0) { throw "Active files on archive list: $($overlap -join ', ')" }
$missingRequired = @($required | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $monitoringRoot $_) -PathType Leaf)
})
$candidates = @($archiveNames | Where-Object {
    Test-Path -LiteralPath (Join-Path $monitoringRoot $_)
})
$archiveRun = (Get-Date -Format 'yyyy-MM-dd_HHmmss_fff') + '_' + ([guid]::NewGuid().ToString('N').Substring(0,8))
$destinationRoot = Join-Path (Join-Path $monitoringRoot 'archive') $archiveRun

Write-Host "SHG monitoring folder: $monitoringRoot"
Write-Host "Archive candidates: $($candidates.Count) top-level items"
foreach ($name in $candidates) { Write-Host "  $name" }
Write-Host "Archive destination: $destinationRoot"
if (-not $IncludeLegacyRunner) { Write-Host 'run-reports-legacy.do is retained (not reviewed/retired).' }
if ($missingRequired.Count -gt 0) {
    Write-Warning "Required active files are missing: $($missingRequired -join ', ')"
}
if (-not $Apply) {
    Write-Host 'PREVIEW ONLY: nothing changed. Use -Apply after the new weekly run succeeds.'
    return
}
if ($missingRequired.Count -gt 0) { throw 'Archive blocked: install the complete new weekly workflow first.' }
if ($candidates.Count -eq 0) { Write-Host 'Nothing remains on the archive allowlist.'; return }
if (Test-Path -LiteralPath $destinationRoot) { throw "Archive destination already exists: $destinationRoot" }

# Inventory all candidate files before moving; refuse links/junctions.
$fileInventory = @()
foreach ($name in $candidates) {
    $source = Join-Path $monitoringRoot $name
    $item = Get-Item -LiteralPath $source -Force
    $entries = @($item)
    if ($item.PSIsContainer) { $entries += @(Get-ChildItem -LiteralPath $source -Recurse -Force) }
    foreach ($entry in $entries) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Archive blocked: link/junction requires separate review: $($entry.FullName)"
        }
        if (-not $entry.PSIsContainer) {
            $relative = $entry.FullName.Substring($monitoringRoot.Length).TrimStart([char]'\')
            $fileInventory += [pscustomobject]@{
                RelativePath = $relative
                SourcePath = $entry.FullName
                ArchivePath = Join-Path $destinationRoot $relative
                Bytes = $entry.Length
                SHA256 = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash
            }
        }
    }
}
$plan = @($candidates | ForEach-Object {
    [pscustomobject]@{
        Item = $_
        SourcePath = Join-Path $monitoringRoot $_
        ArchivePath = Join-Path $destinationRoot $_
        Status = 'Planned'
    }
})
# -Apply -WhatIf reaches this point but creates no folders or manifests.
if (-not $PSCmdlet.ShouldProcess($monitoringRoot, "Move $($candidates.Count) superseded items to $destinationRoot")) { return }

New-Item -ItemType Directory -Path $destinationRoot | Out-Null
$planPath = Join-Path $destinationRoot 'archive-plan.csv'
$fileInventory | Export-Csv -LiteralPath (Join-Path $destinationRoot 'archive-files.csv') -NoTypeInformation -Encoding UTF8
$plan | Export-Csv -LiteralPath $planPath -NoTypeInformation -Encoding UTF8
try {
    foreach ($row in $plan) {
        if (Test-Path -LiteralPath $row.ArchivePath) { throw "Refusing to overwrite: $($row.ArchivePath)" }
        Move-Item -LiteralPath $row.SourcePath -Destination $row.ArchivePath
        $row.Status = 'Moved'
        $plan | Export-Csv -LiteralPath $planPath -NoTypeInformation -Encoding UTF8
        Write-Host "Archived: $($row.Item)"
    }
}
catch {
    Write-Warning "Archive stopped. Already moved items are retained at $destinationRoot. Review archive-plan.csv before retrying."
    throw
}
Write-Host "Archive complete: $destinationRoot"
Write-Host "Files inventoried: $($fileInventory.Count). SHA256 hashes: archive-files.csv"
Write-Host 'No files were deleted. Active workflow files and the live map remain in place.'
Write-Host 'To restore an item, move its archived copy to SourcePath in archive-plan.csv; review any existing destination first.'
