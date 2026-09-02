#!/usr/bin/env bash

# Keep TypeTone on the exact Wayvibes source snapshot reviewed with the plugin.
typetone_wayvibes_commit="b43b76fd3a4181b7bd9029372b93d503ce91dced"
typetone_data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
typetone_wayvibes_vendor_parent="$typetone_data_root/typetone/vendor/wayvibes"
typetone_wayvibes_root="$typetone_wayvibes_vendor_parent/$typetone_wayvibes_commit"
typetone_wayvibes_bin="$typetone_wayvibes_root/wayvibes"
typetone_wayvibes_soundpacks="$typetone_wayvibes_root/soundpacks"
