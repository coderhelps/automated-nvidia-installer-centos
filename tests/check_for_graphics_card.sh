#!/bin/bash

    if lspci | grep -i --color vga | grep --quiet NVIDIA; then
        echo "Found NVIDIA card" # do nothing
    else
        exit 1
    fi
