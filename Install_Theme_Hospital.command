#!/usr/bin/env bash
# ==============================================================================
#  Install_Theme_Hospital.command
#  One-click launcher for macOS Finder.
# ==============================================================================

# Change to the directory where this script is located
cd "$(dirname "$0")" || exit 1

# Execute master setup and deployment script
exec bash "scripts/setup_theme_hospital.sh" "$@"
