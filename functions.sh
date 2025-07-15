#!/bin/bash

modify_sources() {
    set -e

    SOURCE_FILE="/etc/apt/sources.list"
    TMP_FILE="$(mktemp)"
    REQUIRED_COMPONENTS="main contrib non-free non-free-firmware"

    # Match all common variants for Debian 12
    DIST_NAMES="bookworm bookworm-updates bookworm-security bookworm-backports"

    # Build sed script
    sed_script=""
    for dist in $DIST_NAMES; do
        sed_script+="
/^deb\\(-src\\)\\? .* $dist / s#^\\(deb\\(-src\\)\\? .* $dist\\) .*#\\1 $REQUIRED_COMPONENTS#
"
    done

    # Apply sed script to create new file
    sed "$sed_script" "$SOURCE_FILE" > "$TMP_FILE"

    # Replace original file
    sudo cp "$TMP_FILE" "$SOURCE_FILE"
    rm -f "$TMP_FILE"

    # Adding backports lines

    CODENAME=$(lsb_release -sc)
    COMPONENTS="main contrib non-free non-free-firmware"

    echo -e "\nAdding backports lines to /etc/apt/sources.list..."

    sudo tee -a /etc/apt/sources.list > /dev/null <<EOF

# Backports repository
deb http://deb.debian.org/debian $CODENAME-backports $COMPONENTS
deb-src http://deb.debian.org/debian $CODENAME-backports $COMPONENTS
EOF
}

getDecisionYN() {
    read -rp "$1 [Y/n]: " answer
    answer="${answer:-Y}"  # Default to 'Y' if empty (Enter)

    case "$answer" in
        [yY])
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

is_package_installed() {
    local package="$1"

    if dpkg -s "$package" >/dev/null 2>&1; then
        echo -e "'$package' is installed\n"
        return 1
    else
        getDecisionYN "Do you want to install '$package'?"
        decision=$?
        return $((1 - decision))
    fi
}

install_packages() {
    local to_install=()
    local package_installed=1

    for pkg in "$@"; do
        echo -e "===================================================\n"
        is_package_installed "$pkg"
        package_installed=$?

        if [ 0 -eq $package_installed ]; then
            to_install+=("$pkg")
        fi
    done

    echo -e "===================================================\n"
    if [ "${#to_install[@]}" -gt 0 ]; then
        sudo apt install -y "${to_install[@]}"
    fi
}

# ==============================================
# modify sources.list + update + upgrade + install sudo
if ! command -v sudo >/dev/null 2>&1; then
    echo -e "\n==================================================="
    if [[ "$EUID" -ne 0 ]]; then
        exec su -c "\"$0\" $*"
    fi

    # work as root

    if getDecisionYN 'Do you want to modify /etc/apt/sources.list?'; then
        modify_sources
    fi

    apt update -y && apt upgrade -y && apt install -y sudo

    real_user=$(logname)
    export PATH="$PATH:/usr/sbin:/sbin"

    if ! id -nG "$real_user" | grep -qw sudo; then
        usermod -aG sudo "$real_user"
        echo -e "\nre-login required\nand run this script again\n\n"
        exit
    fi
fi

