#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

create_initd_file()
{
    cat > /etc/init.d/$1 << EOF
#! /bin/sh

### BEGIN INIT INFO
# Provides:          $1
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

case "\$1" in
    start)
        $DIR/install-nvidia-drivers.sh
        ;;
    stop|restart|reload)
        ;;
esac
EOF
}

create_initd_file "path1"
