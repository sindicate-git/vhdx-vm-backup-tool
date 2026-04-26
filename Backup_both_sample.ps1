# This is a sanitized portfolio version. Company names, hostnames, internal paths, and client-specific details have been removed.

# Windows VHDX and VM Backup Automation Tool
# Backup_both_sample.ps1

<#
.SYNOPSIS
    Combined Host VHDX and VM folder backup script with defined backup paths.

.DESCRIPTION
    1) Backs up all .vhdx files from specified source drives into a host backup folder.
    2) Uses update-only Robocopy logic to avoid unnecessary duplicate copies.
    3) Announces copied, skipped, and error states clearly.
    4) Mounts the most recent VHDX, scans and repairs volumes if needed, then dismounts.
    5) Backs up VM folders from matching source roots into matching destination roots.
    6) Does not create missing destination folders; missing destinations are skipped and announced.

.NOTES
    This is a sanitized portfolio version.
    Company names, internal hostnames, IP addresses, and client-specific paths have been removed.
#>

####################
# Config & Helpers #
####################

$ProgressPreference = 'SilentlyContinue'

function Expand-FoldersFromPatterns {
    param([string[]]$Patterns)

    foreach ($pattern in $Patterns) {
        Get-ChildItem -Path "$pattern*" -ErrorAction SilentlyContinue |
            Where-Object { $_.PSIsContainer }
    }
}

function Copy-FileWithRobocopy {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$FileName
    )

    $robocopyArgs = @(
        $SourcePath
        $DestPath
        $FileName
        '/NFL'
        '/NDL'
        '/NJH'
        '/NJS'
        '/NC'
        '/NS'
        '/XO'
        '/R:2'
        '/W:2'
    )

    & robocopy @robocopyArgs | Out-Null
    return $LASTEXITCODE
}

function Show-RobocopyResult {
    param(
        [int]$Code,
        [string]$Label
    )

    if ($Code -eq 0) {
        Write-Host "$Label SKIPPED (no changes)" -ForegroundColor Yellow
    }
    elseif ($Code -lt 8) {
        Write-Host "$Label COPIED" -ForegroundColor Green
    }
    else {
        Write-Host "$Label ERROR ($Code)" -ForegroundColor Red
    }
}

function Mount-VHDX-Check-Dismount {
    param([string]$VhdxPath)

    Write-Host ">> Mounting $VhdxPath" -ForegroundColor Cyan

    try {
        Mount-DiskImage -ImagePath $VhdxPath -PassThru | Out-Null
        Start-Sleep -Seconds 2

        $disk = Get-DiskImage -ImagePath $VhdxPath | Get-Disk

        if (-not $disk) {
            Write-Host ">> ERROR: Disk not found" -ForegroundColor Red
            return
        }

        foreach ($vol in Get-Volume -DiskNumber $disk.Number) {
            if ($vol.DriveLetter) {
                Write-Host ">> Checking $($vol.DriveLetter):..." -ForegroundColor Cyan

                $res = Repair-Volume -DriveLetter $vol.DriveLetter -Scan

                if ($res.ScanResult -ne 'Healthy') {
                    Write-Host ">> Repairing $($vol.DriveLetter):" -ForegroundColor Yellow
                    Repair-Volume -DriveLetter $vol.DriveLetter -OfflineScanAndFix | Out-Null
                    Write-Host ">> $($vol.DriveLetter): Repair complete" -ForegroundColor Green
                }
                else {
                    Write-Host ">> $($vol.DriveLetter): Healthy" -ForegroundColor Green
                }
            }
        }
    }
    catch {
        Write-Host ">> ERROR during VHDX check: $_" -ForegroundColor Red
    }
    finally {
        Write-Host ">> Dismounting $VhdxPath" -ForegroundColor Cyan
        Dismount-DiskImage -ImagePath $VhdxPath -ErrorAction SilentlyContinue
    }
}

##########################
# Pattern-Based Matching #
##########################

# -- Host Backup Folders --
# Example destination folders:
# B:\Backup Host Drive
# B:\Backup Host Drives
# B:\Backup VHD
# B:\Backup VHDs
# B:\Host Drive Backup
# B:\Host Drive Backups

$BaseHostNames = @(
    'Backup Host Drive',
    'Backup VHD',
    'Host Drive Backup',
    'Back Up Host Drive'
)

$RawHostPatterns = $BaseHostNames + ($BaseHostNames | ForEach-Object { "$_s" })

$HostBackupPaths = Expand-FoldersFromPatterns (
    $RawHostPatterns | ForEach-Object { "B:\$_" }
) | Select-Object -ExpandProperty FullName

# -- VHDX Source Drives --
# Example source locations:
# A:\Host Drives
# D:\Host Drives
# D:\*.vhdx

$VhdxDrives = @(
    'A:\',
    'D:\'
)

# -- VM Source Folders --
# Example source folders:
# A:\Virtual Machine
# A:\Virtual Machines
# A:\VM Workstation
# A:\VM Workstations

$BaseVmSourceNames = @(
    'Virtual Machine',
    'VM Workstation',
    'IT-VIRTUAL MACHINE'
)

$VmSourceRoot = Expand-FoldersFromPatterns (
    ($BaseVmSourceNames + ($BaseVmSourceNames | ForEach-Object { "$_s" })) |
    ForEach-Object { "A:\$_" }
) | Select-Object -ExpandProperty FullName -First 1

# -- VM Destination Folders --
# Example destination folders:
# B:\VM Backup
# B:\VM Backups
# B:\Backup VM
# B:\Backup VMs
# B:\Virtual Machine Backup
# B:\Virtual Machine Backups

$BaseVmDestNames = @(
    'VM Backup',
    'Backup VM',
    'Virtual Machine Backup',
    'Backup VM Workstation',
    'Backup Virtual Machine'
)

$VmDestRoot = Expand-FoldersFromPatterns (
    ($BaseVmDestNames + ($BaseVmDestNames | ForEach-Object { "$_s" })) |
    ForEach-Object { "B:\$_" }
) | Select-Object -ExpandProperty FullName -First 1

####################
# Main Backup Flow #
####################

# -- Host Backup Path Detection --
$HostBackupPath = $HostBackupPaths |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $HostBackupPath) {
    Write-Host "ERROR: No host backup folder found." -ForegroundColor Red
    exit 1
}

Write-Host "FOUND HOST BACKUP: $HostBackupPath" -ForegroundColor Green

# -- VHDX Backup Section --
Write-Host "`n=== Host VHDX Backup ===" -ForegroundColor Magenta

$vhdxFiles = $VhdxDrives | ForEach-Object {
    Get-ChildItem -Path $_ -Filter '*.vhdx' -Recurse -ErrorAction SilentlyContinue
}

if ($vhdxFiles.Count -eq 0) {
    Write-Host "No VHDX files found." -ForegroundColor Yellow
}
else {
    Write-Host "`nALL HOST VHDX FILES FOUND:" -ForegroundColor Green
    foreach ($file in $vhdxFiles) {
        Write-Host " -> $($file.FullName)" -ForegroundColor Yellow
    }

    $i = 0
    $total = $vhdxFiles.Count

    foreach ($file in $vhdxFiles) {
        $i++

        $destFile = Join-Path $HostBackupPath $file.Name

        Write-Host "[$i/$total] Processing $($file.Name)" -ForegroundColor Cyan

        if (Test-Path $destFile) {
            $sourceTime = (Get-Item $file.FullName).LastWriteTime
            $destTime   = (Get-Item $destFile).LastWriteTime

            if ($destTime -ge $sourceTime) {
                Write-Host "[$i/$total] SKIPPED (up-to-date): $($file.Name)" -ForegroundColor Yellow
                continue
            }
        }

        Write-Host "[$i/$total] Copying $($file.FullName) -> $destFile" -ForegroundColor Cyan

        $rc = Copy-FileWithRobocopy `
            -SourcePath $file.DirectoryName `
            -DestPath $HostBackupPath `
            -FileName $file.Name

        Show-RobocopyResult -Code $rc -Label "[$i/$total]"
    }

    $latest = $vhdxFiles |
        Sort-Object LastWriteTime |
        Select-Object -Last 1

    Write-Host "`n=== Post-Backup VHDX Check ===" -ForegroundColor Magenta

    $latestBackupPath = Join-Path $HostBackupPath $latest.Name

    if (Test-Path $latestBackupPath) {
        Mount-VHDX-Check-Dismount -VhdxPath $latestBackupPath
    }
    else {
        Write-Host "SKIPPED VHDX check because latest backup does not exist: $latestBackupPath" -ForegroundColor Yellow
    }
}

# -- VM Folder Backup Section --
Write-Host "`n=== VM Folder Backups ===" -ForegroundColor Magenta

if (-not $VmSourceRoot) {
    Write-Host "ERROR: VM source root not found." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $VmSourceRoot)) {
    Write-Host "ERROR: VM source '$VmSourceRoot' not found." -ForegroundColor Red
    exit 1
}

if (-not $VmDestRoot) {
    Write-Host "ERROR: VM destination root not found." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $VmDestRoot)) {
    Write-Host "ERROR: VM destination root '$VmDestRoot' not found." -ForegroundColor Red
    exit 1
}

Write-Host "FOUND VM SOURCE ROOT -> $VmSourceRoot" -ForegroundColor Green
Write-Host "FOUND VM DESTINATION ROOT -> $VmDestRoot" -ForegroundColor Green

$vmFolders = Get-ChildItem -Path $VmSourceRoot -ErrorAction SilentlyContinue |
    Where-Object { $_.PSIsContainer }

if ($vmFolders.Count -eq 0) {
    Write-Host "No VM folders found under source root." -ForegroundColor Yellow
}
else {
    Write-Host "`nVM FOLDERS FOUND:" -ForegroundColor Green
    foreach ($vm in $vmFolders) {
        Write-Host " -> $($vm.Name)" -ForegroundColor Yellow
    }

    $j = 0
    $vmTotal = $vmFolders.Count

    foreach ($vm in $vmFolders) {
        $j++

        $vmDest = Join-Path $VmDestRoot $vm.Name

        if (-not (Test-Path $vmDest)) {
            Write-Host "[$j/$vmTotal] SKIPPED (no destination): $($vm.Name)" -ForegroundColor Yellow
            continue
        }

        Write-Host "[$j/$vmTotal] Backing up $($vm.Name)" -ForegroundColor Cyan
        Write-Host "[$j/$vmTotal] Copying $($vm.FullName) -> $vmDest" -ForegroundColor Cyan

        $vmRobocopyArgs = @(
            $vm.FullName
            $vmDest
            '*.*'
            '/E'
            '/XO'
            '/R:2'
            '/W:2'
        )

        & robocopy @vmRobocopyArgs | Out-Null

        Show-RobocopyResult -Code $LASTEXITCODE -Label "[$j/$vmTotal]"
    }
}

Write-Host "`nAll backups complete!" -ForegroundColor Green
