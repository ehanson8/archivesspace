#!/bin/bash
#
# archivesspace          Start the ArchivesSpace archival management system
#
# chkconfig: 2345 90 5
# description: Start the ArchivesSpace archival management system
#

### BEGIN INIT INFO
# Provides: archivesspace
# Required-Start: $local_fs $network $syslog
# Required-Stop: $local_fs $syslog
# Should-Start: $syslog
# Should-Stop: $network $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Start the ArchivesSpace archival management system
# Description:       Start the ArchivesSpace archival management system
### END INIT INFO


# http://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
function readlink_dash_f {
    max_iterations=32

    target_file=$1

    cd "`dirname "$target_file"`"
    target_file="`basename "$target_file"`"

    # iterate down a (possible) chain of symlinks
    i=0
    while [ -L "$target_file" ]
    do
        target_file="`readlink "$target_file"`"
        cd "`dirname "$target_file"`"
        target_file="`basename "$target_file"`"

        if [ $i -gt $max_iterations ]; then
            echo "ERROR: maximum iteration count reached ($max_iterations)" > /dev/stderr
            return 1
        fi

        i=$[i + 1]
    done

    # Compute the canonicalized name by finding the physical path 
    # for the directory we're in and appending the target file.
    result="`pwd -P`/$target_file"

    echo $result
    return 0
}




cd "`dirname $0`"

# Check for Java
java -version &>/dev/null

if [ "$?" != "0" ]; then
    echo "Could not run your 'java' executable."
    echo "Please ensure that Java 1.6 (or above) is installed and on your PATH"
    exit
fi

if [ ! -e "scripts/find-base.sh" ]; then
    cd "$(dirname `readlink_dash_f "$0"`)"
fi

export ASPACE_LAUNCHER_BASE="$(scripts/find-base.sh)"

if [ "$ASPACE_LAUNCHER_BASE" = "" ]; then
    echo "Couldn't find launcher base directory!  Aborting."
    exit
fi

echo "ArchivesSpace base directory: $ASPACE_LAUNCHER_BASE"

if [ "$ARCHIVESSPACE_USER" = "" ]; then
    ARCHIVESSPACE_USER=
fi

export JAVA_OPTS="-Darchivesspace-daemon=yes $JAVA_OPTS"

# Wow.  Not proud of this!
export JAVA_OPTS="`echo $JAVA_OPTS | sed 's/\([#&;\`|*?~<>^(){}$\,]\)/\\\\\1/g'`"

if [ "$ASPACE_JAVA_XMX" = "" ]; then
    ASPACE_JAVA_XMX="-Xmx1024m"
fi

if [ "$ASPACE_JAVA_XSS" = "" ]; then
    ASPACE_JAVA_XSS="-Xss2m"
fi

if [ "$ASPACE_JAVA_MAXPERMSIZE" = "" ]; then
    ASPACE_JAVA_MAXPERMSIZE="-XX:MaxPermSize=256m"
fi

export JRUBY=
for dir in "$ASPACE_LAUNCHER_BASE"/gems/gems/jruby-*; do
    JRUBY="$JRUBY:$dir/lib/*"
done

startup_cmd="java "$JAVA_OPTS"  \
        $ASPACE_JAVA_XMX $ASPACE_JAVA_XSS $ASPACE_JAVA_MAXPERMSIZE -Dfile.encoding=UTF-8 \
        -cp \"lib/*:launcher/lib/*$JRUBY\" \
        org.jruby.Main --disable-gems --1.9 \"launcher/launcher.rb\""


export PIDFILE="$ASPACE_LAUNCHER_BASE/data/.archivesspace.pid"


case "$1" in
    start)
        if [ -e "$PIDFILE" ]; then
            pid=`cat $PIDFILE 2>/dev/null`

            if [ "$pid" != "" ] && kill -0 $pid &>/dev/null; then
                echo "There already seems to be an instance running (PID: $pid)"
                exit
            fi
        fi

        shellcmd="bash"
        if [ "$ARCHIVESSPACE_USER" != "" ]; then
            shellcmd="su $ARCHIVESSPACE_USER"
        fi

        $shellcmd -c "cd '$ASPACE_LAUNCHER_BASE';
          (
             exec 0<&-; exec 1>&-; exec 2>&-;
             $startup_cmd &> \"logs/archivesspace.out\" &
             echo \$! > \"$PIDFILE\"
          ) &
          disown $!"

        echo "ArchivesSpace started!  See logs/archivesspace.out for details."
        ;;
    stop)
        pid=`cat $PIDFILE 2>/dev/null`
        if [ "$pid" != "" ]; then
            kill -0 $pid &>/dev/null
            if [ "$?" = "0" ]; then
                echo -n "Shutting down ArchivesSpace (running as PID $pid)... "
                kill $pid
                echo "done"
            fi

            rm -f "$PIDFILE"
        else
            echo "Couldn't find a running instance to stop"
        fi
        ;;
    "")
        # Run in foreground mode
        (cd "$ASPACE_LAUNCHER_BASE"; bash -c "$startup_cmd 2>&1 | tee 'logs/archivesspace.out'")
        ;;
    *)
        echo "Usage: $0 [start|stop]"
        exit 1
        ;;

esac
