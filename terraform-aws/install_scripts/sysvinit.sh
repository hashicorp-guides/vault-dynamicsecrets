#!/bin/sh
#
# consul - this script manages the consul agent
#
# chkconfig:   345 95 05
# processname: consul

### BEGIN INIT INFO
# Provides:       consul
# Required-Start: $local_fs $network
# Required-Stop:  $local_fs $network
# Default-Start: 3 4 5
# Default-Stop:  0 1 2 6
# Short-Description: Manage the consul agent
### END INIT INFO

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0

exec="/usr/bin/{{NAME}}"
prog=${exec##*/}

lockfile="/var/lock/subsys/$prog"
pidfile="/var/run/${prog}.pid"
logfile="/var/log/${prog}.log"
sysconfig="/etc/sysconfig/$prog"
confdir="/etc/${prog}"

[ -f $sysconfig ] && . $sysconfig

export GOMAXPROCS=${GOMAXPROCS:-2}

start() {
    [ -x $exec ] || exit 5
    [ -d $confdir ] || exit 6

    echo -n $"Starting $prog: "
    touch $logfile $pidfile

    daemon \
        --pidfile=$pidfile \
        --user=root \
        "{ $exec {{CMD}} $OPTIONS >> $logfile 2>&1 & } ; echo \$! >| $pidfile "
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && touch $lockfile
    return $RETVAL
}

stop() {
    echo -n $"Stopping $prog: "
    killproc -p $pidfile $exec -INT 2>> $logfile
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f $pidfile $lockfile
    return $RETVAL
}

restart() {
    stop
    while :
    do
        ss -pl | fgrep "((\"$prog\"," > /dev/null
        [ $? -ne 0 ] && break
        sleep 0.1
    done
    start
}

reload() {
    echo -n $"Reloading $prog: "
    killproc -p $pidfile $exec -HUP
    echo
}

force_reload() {
    restart
}

configtest() {
    $exec configtest -config-dir=$confdir
}

rh_status() {
    status $prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart)
        $1
        ;;
    reload|force-reload)
        rh_status_q || exit 7
        $1
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 7
        restart
        ;;
    configtest)
        $1
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
        exit 2
esac

exit $?