# felineOS: look in /usr/share/felineos first for app entries (.desktop files).
# Lets felineOS hide or tweak launcher entries without touching other packages' files.
case ":${XDG_DATA_DIRS}:" in
    *:/usr/share/felineos:*) ;;
    *) export XDG_DATA_DIRS="/usr/share/felineos:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;;
esac
