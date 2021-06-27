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
SERVER1_PROC="onh_test_server1"
SERVER2_PROC="onh_test_server2"
ONH_PROC="openNetworkHMI"
if pidof "$SERVER1_PROC" >/dev/null
then
    echo "$SERVER1_PROC is running!"
else

	if pidof "$SERVER2_PROC" >/dev/null
    then
        echo "$SERVER2_PROC is running!"
    else

		# Check ONH service
		if pidof "$ONH_PROC" >/dev/null
		then
		    echo "$ONH_PROC is running!"
		else

			# Remove old exec
	    	rm -f bin/onh/openNetworkHMI
	    	rm -f bin/onh_test_server1
	    	rm -f bin/onh_test_server2

	    	# Check if openNetworkHMI is compiled
			if [ ! -f ../openNetworkHMI_service/build/openNetworkHMI ]
			then
				echo "openNetworkHMI service is not compiled - compile services"
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

	    	cp ../openNetworkHMI_service/build/openNetworkHMI bin/onh/openNetworkHMI
	    	cp ../openNetworkHMI_service/build/test/test_server1/onh_test_server1 bin/
	    	cp ../openNetworkHMI_service/build/test/test_server2/onh_test_server2 bin/

	    	# Check if test DB exist
			if [ ! -f ../openNetworkHMI_web/distFiles/testDB/db.sql ]
			then
				echo "openNetworkHMI test DB file not exist - generate test DB file"
				return 1
			fi

			echo "Prepare DB..."

			# Prepare DB
			DBUSR=$(sed -n '3p' bin/onh/dbConn.conf)
			DBPASS=$(sed -n '4p' bin/onh/dbConn.conf)
			mysql -u "$DBUSR" -p"$DBPASS" openNetworkHMI_DB_test < ../openNetworkHMI_web/distFiles/testDB/db.sql 

			# Get server app port number
			cd ../openNetworkHMI_web
			PRT=$(APP_ENV=test php bin/console app:onh-server-port)
	    
		    # Go to bin directory
		    cd ../tests/bin

		    # Run test server 1 app in background
	        ./onh_test_server1 > onh_test_server1_log 2>&1 &
	        SERVER1_PID=$!

	        # Run test server 2 app in background
	        ./onh_test_server2 > onh_test_server2_log 2>&1 &
	        SERVER2_PID=$!

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

			# Wait until Modbus is initialized (waiting on modbusInited file - server is creating it after startup)
	        echo "Wait on Modbus initialization..."
	        MB_INITED=0
	        while [ $MB_INITED -eq 0 ]
	        do
	            if [ -f "modbusInited" ]; then
	                MB_INITED=1
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
					# close server 1 test app
					kill $SERVER1_PID

					# close server 2 test app
					kill -9 $SERVER2_PID

					echo "ONH service not started!"
					exit 1
				fi
			done

		    # Run tests
		    cd ../../../openNetworkHMI_web

			php ./vendor/bin/phpunit --testsuite function

			# close onh service
			echo "Close ONH service: "
			APP_ENV=test php bin/console app:onh-exit

			# Wait until onh service closed
			wait $ONH_PID

			# close server 1 test app
			kill $SERVER1_PID

		    # Wait on server app
		    wait $SERVER1_PID

		    # close server 2 test app
			kill -9 $SERVER2_PID

			# Wait on server app
		    wait $SERVER2_PID
		fi
	fi
    
fi
