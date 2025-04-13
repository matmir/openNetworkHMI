#!/bin/sh

# Run all cpp tests

# Change directory to the script directory
SCRIPTDIR=$(dirname $0)
cd $SCRIPTDIR

# Base script directory
BASEDIR=$(pwd)

# Check if bin directory exist
if [ ! -d bin/ ]
then
    echo "Create bin/ directory"
    mkdir bin
fi

# Check if server test app is closed
SERVER1_PROC="onh_test_server1"
SERVER2_PROC="onh_test_server2"
if pidof "$SERVER1_PROC" >/dev/null
then
    echo "$SERVER1_PROC is running!"
else

    if pidof "$SERVER2_PROC" >/dev/null
    then
        echo "$SERVER2_PROC is running!"
    else

        # Remove old exec
        rm -f bin/openNetworkHMI_test
        rm -f bin/onh_test_server1
        rm -f bin/onh_test_server2

        # Check if openNetworkHMI test program is compiled
        if [ ! -f ../openNetworkHMI_service/build/test/tests/openNetworkHMI_test ]
        then
            echo "openNetworkHMI test app is not compiled - compile services"
            return 1
        fi

        # Check if test server 1 is compiled
        if [ ! -f ../openNetworkHMI_service/build/test/test_server1/onh_test_server1 ]
        then
            echo "openNetworkHMI test server 1 app is not compiled - compile services"
            return 1
        fi

        # Check if test server 2 is compiled
        if [ ! -f ../openNetworkHMI_service/build/test/test_server2/onh_test_server2 ]
        then
            echo "openNetworkHMI test server 2 app is not compiled - compile services"
            return 1
        fi

        # Copy new exec
        cp ../openNetworkHMI_service/build/test/tests/openNetworkHMI_test bin/
        cp ../openNetworkHMI_service/build/test/test_server1/onh_test_server1 bin/
        cp ../openNetworkHMI_service/build/test/test_server2/onh_test_server2 bin/
        
        # Go to bin directory
        cd bin

        # Run test server 1 app in background
        ./onh_test_server1 > onh_test_server1_log 2>&1 &
        SERVER1_PID=$!

        # Run test server 2 app in background
        ./onh_test_server2 > onh_test_server2_log 2>&1 &
        SERVER2_PID=$!

        # Run CPP tests
        ./openNetworkHMI_test

        echo "Wait on test servers closed..."
        # Wait on server app
        wait $SERVER1_PID
        wait $SERVER2_PID
        echo "OK"
    fi
fi
