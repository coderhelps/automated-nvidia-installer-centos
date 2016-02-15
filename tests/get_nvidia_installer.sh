#!/bin/bash

# check for installer relative first
# then check on the machine
# if not on machine try to download it

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "$DIR"

if [ -f "$DIR/nvidia.run" ]; then
    cp $DIR/nvidia.run /usr/src/nvidia.run
elif [ ! -f "/usr/src/nvidia.run" ]; then
    wget -O /usr/src/nvidia.run http://us.download.nvidia.com/XFree86/Linux-x86_64/358.16/NVIDIA-Linux-x86_64-358.16.run
fi
