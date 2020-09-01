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
SERVER_PROC="openNetworkHMI_cpp_test_server"
if pidof "$SERVER_PROC" >/dev/null
then
    echo "$SERVER_PROC is running!"
else

    # Remove old exec
    rm -f bin/openNetworkHMI_test
    rm -f bin/openNetworkHMI_cpp_test_server1

    # Check if openNetworkHMI test program is compiled
    if [ ! -f ../openNetworkHMI_service/test/tests/build/app/openNetworkHMI_test ]
    then
        echo "openNetworkHMI test app is not compiled - compile services"
        return 1
    fi

    # Check if test server is compiled
    if [ ! -f ../openNetworkHMI_service/test/test_server1/build/app/openNetworkHMI_cpp_test_server1 ]
    then
        echo "openNetworkHMI test server 1 app is not compiled - compile services"
        return 1
    fi

    # Copy new exec
    cp ../openNetworkHMI_service/test/tests/build/app/openNetworkHMI_test bin/
    cp ../openNetworkHMI_service/test/test_server1/build/app/openNetworkHMI_cpp_test_server1 bin/
    
    # Go to bin directory
    cd bin

    # Run test server app in background
    ./openNetworkHMI_cpp_test_server1 &

    SERVER_PID=$!

    # Wait until SHM region is created and initialized (waiting on shmInited file - server is creating it after startup)
    echo "Wait on SHM initialization..."
    SHM_INITED=0
    while [ $SHM_INITED -eq 0 ]
	do
		if [ -f "shmInited" ]; then
		    SHM_INITED=1
		fi
	done
	echo "SHM initialized"

    # Run CPP tests
    ./openNetworkHMI_test

    # Wait on server app
    wait $SERVER_PID
fi
