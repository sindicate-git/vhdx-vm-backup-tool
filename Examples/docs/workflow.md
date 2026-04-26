# This is a sanitized portfolio version. Company names, hostnames, internal paths, and client-specific details have been removed.

# Workflow

## Overview

This backup tool automates host VHDX and VM folder backups on Windows using PowerShell and Robocopy.

## Backup Flow

1. Locate existing backup folders.
2. Search configured source drives for VHDX files.
3. Copy only changed files using Robocopy update-only logic.
4. Announce copied, skipped, and error states.
5. Mount the latest VHDX backup.
6. Scan volumes for errors.
7. Repair only when needed.
8. Dismount the VHDX.
9. Process VM folder backups using existing source and destination folders.

## Design Notes

- No destination folders are created automatically.
- Missing destinations are skipped and announced.
- Robocopy exit codes are converted into clear technician-facing messages.
- Output uses consistent `->` arrows for readability.
