#!/bin/sh

echo "Starting SSH ..."
service ssh start

if [ -z "$FQDN" ]; then
    HOSTNAME="localhost"
else
    HOSTNAME=$FQDN
fi

CLASSPATH=protege.jar:looks.jar:driver.jar:driver0.jar:driver1.jar:driver2.jar
MAINCLASS=edu.stanford.smi.protege.server.Server

# ------------------- JVM Options ------------------- 
# MAX_MEMORY=-Xmx500M
# MAX_MEMORY=-Xmx2048M
MAX_MEMORY=-Xmx4096M
HEADLESS=-Djava.awt.headless=true
CODEBASE_URL=file:/root/Protege_3.5/protege.jar
CODEBASE=-Djava.rmi.server.codebase=$CODEBASE_URL
HOSTNAME_PARAM=-Djava.rmi.server.hostname=$HOSTNAME
TX="-Dtransaction.level=READ_COMMITTED"
LOG4J_OPT="-Dlog4j.configuration=file:log4j.xml"

OPTIONS="$MAX_MEMORY $HEADLESS $CODEBASE $HOSTNAME_PARAM ${TX} ${LOG4J_OPT}"

#
# Instrumentation debug, delay simulation,  etc
#
PORTOPTS="-Dprotege.rmi.server.port=5200 -Dprotege.rmi.registry.port=5100 -Dserver.use.compression=true"
# DEBUG_OPT="-Xdebug -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n"

OPTIONS="${OPTIONS} ${PORTOPTS} ${DEBUG_OPT}"
# ------------------- JVM Options ------------------- 

# ------------------- Cmd Options -------------------
# If you want automatic saving of the project, 
# setup the number of seconds in SAVE_INTERVAL_VALUE
SAVE_INTERVAL=-saveIntervalSec=120
# ------------------- Cmd Options -------------------

METAPROJECT=/opt/EssentialAM/server/metaproject.pprj

/opt/java/openjdk/bin/rmiregistry -J$HOSTNAME_PARAM -J-Djava.class.path=$CLASSPATH 5100 &
/opt/java/openjdk/bin/java -cp $CLASSPATH $TX $OPTIONS $MAINCLASS $SAVE_INTERVAL $METAPROJECT
