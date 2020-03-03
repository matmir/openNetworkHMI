#!/bin/sh

# Run function test openNetworkHMI

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

# Check if bin/onh directory exist
if [ ! -d bin/onh ]
then
    echo "Create bin/onh directory"
    mkdir bin/onh
fi

# Check service DB configuration file
if [ ! -f "bin/onh/dbConn.conf" ]
then
	echo "Generate default service DB config file"
    echo "openNetworkHMI_DB_test\nlocalhost\nadmin\nadmin" > bin/onh/dbConn.conf
fi

# Check if server test app is closed
SERVER_PROC="openNetworkHMI_cpp_test_server"
ONH_PROC="openNetworkHMI"
if pidof "$SERVER_PROC" >/dev/null
then
    echo "$SERVER_PROC is running!"
else

	# Check ONH service
	if pidof "$ONH_PROC" >/dev/null
	then
	    echo "$ONH_PROC is running!"
	else

		# Remove old exec
    	rm -f bin/onh/openNetworkHMI
    	rm -f bin/openNetworkHMI_cpp_test_server

    	# Check if openNetworkHMI is compiled
		if [ ! -f ../openNetworkHMI_service/build/app/openNetworkHMI ]
		then
			echo "openNetworkHMI service is not compiled - compile services"
			return 1
		fi

		# Check if test server is compiled
		if [ ! -f ../openNetworkHMI_service/test_server/build/app/openNetworkHMI_cpp_test_server ]
		then
			echo "openNetworkHMI test server app is not compiled - compile services"
			return 1
		fi

    	cp ../openNetworkHMI_service/build/app/openNetworkHMI bin/onh/openNetworkHMI
    	cp ../openNetworkHMI_service/test_server/build/app/openNetworkHMI_cpp_test_server bin/

    	# Check if test DB exist
		if [ ! -f ../openNetworkHMI_web/distFiles/testDB/db.sql ]
		then
			echo "openNetworkHMI test DB file not exist - generate test DB file"
			return 1
		fi

		echo "Prepare DB..."
		# Prepare DB
		mysql -u admin -padmin openNetworkHMI_DB_test < ../openNetworkHMI_web/distFiles/testDB/db.sql 

		# Get server app port number
		cd ../openNetworkHMI_web
		PRT=$(APP_ENV=test php bin/console app:onh-server-port)
    
	    # Go to bin directory
	    cd ../tests/bin

	    # Run test server app in background
	    ./openNetworkHMI_cpp_test_server > onhServerOutLog 2>&1 &
	    SERVER_PID=$!

	    # Wait until SHM region is created and initialized (waiting on shmInited file - server is creating it after startup)
	    echo "Wait on SHM initialization..."
	    SHM_INITED=0
	    while [ $SHM_INITED -eq 0 ]
		do
			if [ -f "shmInited" ]; then
			    SHM_INITED=1
			else
				sleep 0.1
			fi
		done

		echo "Start ONH service..."
		# Run openNetworkHMI app in background
		cd onh
		rm -rf logs

	    ./openNetworkHMI test > onhOutLog 2>&1 &
	    ONH_PID=$!

	    echo "Wait on start..."
	    # Wait until strat
	    SCK=$(lsof -i:$PRT)
	    while [ -z "$SCK" ]
		do
			sleep 0.1
			# Check if service is running
			if ps -p $ONH_PID > /dev/null
			then
			   	SCK=$(lsof -i:$PRT)
			else
				# close server test app
				kill $SERVER_PID

				echo "ONH service not started!"
				exit 1
			fi
		done

	    # Run tests
	    cd ../../../openNetworkHMI_web

		./bin/phpunit --testsuite function

		# close onh service
		echo "Close ONH service: "
		APP_ENV=test php bin/console app:onh-exit

		# Wait until onh service closed
		wait $ONH_PID

		# close server test app
		kill $SERVER_PID

	    # Wait on server app
	    wait $SERVER_PID
	fi
    
fi
