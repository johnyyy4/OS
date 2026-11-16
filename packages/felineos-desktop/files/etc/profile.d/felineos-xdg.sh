# felineOS: make our defaults visible to apps without touching other packages' files.
#  - XDG_DATA_DIRS:   /usr/share/felineos holds launcher (.desktop) overrides
#  - XDG_CONFIG_DIRS: /usr/share/felineos/config holds default app configs (fuzzel).
#                     kitty ignores it, so its default is in /etc/xdg/kitty instead.
#  Anything in ~/.config still wins over these.
case ":${XDG_DATA_DIRS}:" in
    *:/usr/share/felineos:*) ;;
    *) export XDG_DATA_DIRS="/usr/share/felineos:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;;
esac
case ":${XDG_CONFIG_DIRS}:" in
    *:/usr/share/felineos/config:*) ;;
    *) export XDG_CONFIG_DIRS="/usr/share/felineos/config:${XDG_CONFIG_DIRS:-/etc/xdg}" ;;
esac
