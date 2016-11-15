#! /bin/sh

NAME=some-jar-service
PORT=8212
USR=/home/$NAME/bin
JAR=${USR}/${NAME}.jar
LOG=/home/$NAME/log/$NAME-$PORT.log
PID=$USR/$NAME-$PORT.pid

export JAVA_HOME=/usr/bin/java
export HOME=/home/${NAME}

d_start() {
  if [ -f $PID ]; then
    PID_VALUE=`cat $PID`
    if [ ! -z "$PID_VALUE" ]; then
      PID_VALUE=`ps ax | grep $PID_VALUE | grep -v grep | awk '{print $1}'`
      if [ ! -z "$PID_VALUE" ]; then
        exit 1;
      fi
    fi
  fi

  PREV_DIR=`pwd`
  cd $USR
  exec $JAVA_HOME -Xmx1g -jar ${JAR} ${PORT} >> $LOG 2>&1 &
  echo $! > $PID
  cd $PREV_DIR
}

d_stop() {
  if [ -f $PID ]; then
    PID_VALUE=`cat $PID`
    if [ ! -z "$PID_VALUE" ]; then
      PID_VALUE=`ps ax | grep $PID_VALUE | grep -v grep | awk '{print $1}'`
      if [ ! -z "$PID_VALUE" ]; then
        kill $PID_VALUE
        WAIT_TIME=0
        while [ `ps ax | grep $PID_VALUE | grep -v grep | wc -l` -ne 0 -a "$WAIT_TIME" -lt 2 ]
        do
          sleep 1
          WAIT_TIME=$(expr $WAIT_TIME + 1)
        done
        if [ `ps ax | grep $PID_VALUE | grep -v grep | wc -l` -ne 0 ]; then
          WAIT_TIME=0
          while [ `ps ax | grep $PID_VALUE | grep -v grep | wc -l` -ne 0 -a "$WAIT_TIME" -lt 15 ]
          do
            sleep 1
            WAIT_TIME=$(expr $WAIT_TIME + 1)
          done
          echo
        fi
        if [ `ps ax | grep $PID_VALUE | grep -v grep | wc -l` -ne 0 ]; then
          kill -9 $PID_VALUE
        fi
      fi
    fi
    rm -f $PID
  fi
}

case "$1" in
  start)
    d_start
  ;;
  stop)
    d_stop
  ;;
  *)
    echo "Usage: $0 {start|stop|restart}" >&2
    exit 1
  ;;
esac

exit 0
