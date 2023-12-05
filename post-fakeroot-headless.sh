get_headless_parameter () {
    echo $ZEBRAFISH_HEADLESS | xargs -n1 | grep -e ^$1= | tail -n1 | cut -d= -f2  # tail: Last definition wins.
}

if [ -n "$ZEBRAFISH_HEADLESS" ]; then
    echo "Configuring headless defaults ..."

    DEFAULT_DIR="$TARGET_DIR/etc/default/"

    echo DEFAULT_DIR=$DEFAULT_DIR
    ls $DEFAULT_DIR

    headless_font=$(get_headless_parameter "font")
    headless_keymap=$(get_headless_parameter "keymap")
    headless_hostname=$(get_headless_parameter "hostname")

    [ -n "$headless_font" ] && [ -n "$headless_keymap" ] && echo "FONT=$headless_font"     >  $DEFAULT_DIR/console || true
    [ -n "$headless_font" ] && [ -n "$headless_keymap" ] && echo "KEYMAP=$headless_keymap" >> $DEFAULT_DIR/console || true

    [ -n "$headless_hostname" ] || headless_hostname="zebrafish-headless"
    echo "HOSTNAME=$headless_hostname" > $DEFAULT_DIR/hostname
fi
