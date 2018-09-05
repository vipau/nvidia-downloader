#!/bin/bash

depcheck () {
    if ! command -v "$1" >/dev/null 2>&1
    then
        echo "I require $1 ($2) but it's not installed."
        exit 1
    fi
}

depcheck curl curl
depcheck grep grep
depcheck sed sed
depcheck wget wget

help="nvidia-downloader [-h] [-d] [-i] [-s] [-p] -- script to check/download/install nvidia drivers

When run with no options, we will check lastest driver versions.
Only 64bit Linux drivers are supported for now.
They will install with 32bit compat libraries and DKMS, no nvidia-xconfig.
Nvidia installers will be saved so you can use them for --uninstall

options:
    -h  Show this help
    -d  Download the driver (without installing)
    -i  Install the driver after download (requires root and tty)
    -s  Use stable (long lived) driver instead of beta (short lived) drivers.
        NOT RECOMMENDED: Stable drivers often break with new kernels and are missing important Vulkan features.
    -p  Specify a custom path to save drivers to (default is ~/nvidia)"

unset opt ninstall nvdown nstable dir installready

while getopts ":hidsp:" opt; do
    case $opt in
        h)
            echo "$help"
            exit 0
            ;;
        i)
            ninstall=1
            ;;
        d)
            nvdown=1
            ;;
        s)
            nstable=1
            ;;
        p)
            dir="$OPTARG"
            ;;
    esac
done

if [ ! -z "$ninstall" ]; then
        if [ $(id -u) -ne 0 ]; then
            echo "Need root to install the driver."
            exit 1
        fi
        if [ "$DISPLAY" ] || [ "$WAYLAND_DISPLAY" ] || [ "$MIR_SOCKET" ]; then
            echo "Graphical session detected. You can only install drivers from a tty."
            exit 1
        fi
fi
# time for checky checherino... god help
shortv=$(curl --silent --stderr - 'https://www.nvidia.com/object/unix.html' | grep -m 1 'Latest Short' | sed 's/.*\">\(.*\)<\/.*/\1/g')
longv=$(curl --silent --stderr - 'https://www.nvidia.com/object/unix.html' | grep -m 1 'Latest Long' | sed 's/.*\">\(.*\)<\/.*/\1/g') 
echo -e "Lastest Short Lived (beta) driver: $shortv \nLastest Long Lived (stable) driver: $longv\n"
if [ -z "$nvdown" ]; then echo -e "Check -h for help."; fi

# dear NVIDIA, if you're reading this,
# please don't change downloads URL or require a cookie. thx
if [ ! -z "$nvdown" ]; then
    if [ -z "$dir" ]; then dir="$HOME/nvidia"; fi
    [ -d "$dir" ] || mkdir -p "$dir"
    if [ -z "$nstable" ]; then vers=$shortv; else vers=$longv; fi

    echo "WARNING: By downloading/installing NVIDIA drivers you explicitly agree to the 'License For Customer Use of NVIDIA Software'"

    nvname="NVIDIA-Linux-x86_64-$vers.run"
    nvpath="http://us.download.nvidia.com/XFree86/Linux-x86_64/$vers/$nvname"

    wget -q --show-progress -O "$dir/$nvname" "$nvpath"
    if [ -f "$dir/$nvname" ]; then
        echo "File downloaded successfully."
    else
        echo "Download error!"
        if [ ! -z "$ninstall" ]; then echo "Cannot install."; exit 1; fi
    fi
    if [ ! -z "$ninstall" ]; then
        sh "$dir/$nvname" --silent --disable-nouveau --dkms --install-libglvnd
        echo "Driver installed."
    fi
fi
