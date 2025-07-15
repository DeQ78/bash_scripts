#!/bin/bash

source ./functions.sh

# ==============================================
# install console tools
install_packages gpm curl htop git nmap make openssl original-awk sed


# install desktop cinnamon + tools
is_package_installed cinnamon
pkg_installed=$?
if [ 0 -eq $pkg_installed ]; then
    getDecisionYN "Do you want to install 'cinnamon' with out recommends (minimum additional apps)?"
    install_it=$?
    if [ 1 -eq $install_it ]; then
        sudo apt install -y --no-install-recommends cinnamon xorg
        sudo apt install lightdm
    fi
fi

