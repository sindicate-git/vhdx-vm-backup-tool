
# vhdx-vm-backup-tool
This is a sanitized portfolio version. Company names, hostnames, internal paths, and client-specific details have been removed.

Built a PowerShell-based backup automation tool for Windows host VHDX files and VM folders. The script performs flexible folder discovery, update-only Robocopy transfers, skip/copy/error reporting, post-backup VHDX mounting, volume health scanning, automatic repair when needed, and clean dismounting. It was designed to reduce manual backup work.
# Windows VHDX and VM Backup Automation Tool

PowerShell automation for backing up Windows VHDX files and VM folders using Robocopy.

## Features

- Flexible source and destination folder discovery
- Singular/plural folder name matching
- Update-only Robocopy transfers using `/XO`
- Clear status output for copied, skipped, and error states
- VHDX mount, scan, repair, and dismount workflow
- No automatic folder creation in production mode
- Designed for technician-friendly execution from PowerShell or RMM tools

## Skills Demonstrated

- PowerShell scripting
- Windows systems administration
- Robocopy automation
- VHDX handling
- Disk/volume health checks
- Defensive scripting
- Backup workflow automation
