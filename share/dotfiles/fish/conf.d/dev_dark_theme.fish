# === Dev High-Contrast Dark Theme ===

# Base text
set -g fish_color_normal normal

# Code structure
set -g fish_color_command brcyan
set -g fish_color_keyword brmagenta
set -g fish_color_quote bryellow
set -g fish_color_param white
set -g fish_color_option white

# Flow / operators
set -g fish_color_redirection 5f87af # default: brblue
set -g fish_color_end 5f87af # default: brblue
set -g fish_color_operator brcyan
set -g fish_color_escape brcyan

# Errors / alerts (high contrast is key here)
set -g fish_color_error brred --bold
set -g fish_color_cancel -r

# Comments / hints
set -g fish_color_comment brblack
set -g fish_color_autosuggestion brblack

# Search / selection (important for history + pager)
set -g fish_color_search_match --background=brblack
set -g fish_color_selection --background=brblue --bold

# Directories / paths (very important for dev UX)
set -g fish_color_cwd brgreen
set -g fish_color_cwd_root red

# User / host (useful in SSH + dev boxes)
set -g fish_color_user bryellow
set -g fish_color_host 5f87af # default: brblue
set -g fish_color_host_remote brcyan

# Status indicator
set -g fish_color_status brred

# Pager (tab completion UI)
set -g fish_pager_color_completion normal
set -g fish_pager_color_description brblack
set -g fish_pager_color_prefix brcyan --bold
set -g fish_pager_color_progress brwhite --background=brblue
set -g fish_pager_color_selected_background --background=brblack
