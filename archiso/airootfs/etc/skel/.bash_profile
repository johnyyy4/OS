# ~/.bash_profile (felineOS)
[[ -f ~/.bashrc ]] && . ~/.bashrc

# Start Hyprland automatically when logging in on the first virtual terminal.
# If it exits or fails to start, you land back in this shell.
if [[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]] && command -v start-hyprland >/dev/null; then
    start-hyprland
fi
