#!/bin/sh

# openNetworkHMI installation script

# Change directory to the install script
SCRIPTDIR=$(dirname $0)
cd $SCRIPTDIR

# Base script directory
BASEDIR=$(pwd)

# Default branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Default submodules checkout
BRANCH_CHECKOUT=1

# Default install ask flag
ONH_ASK=0

# Default install with tests
ONH_TEST=0

# Input parameters
PARAM_CHECKOUT="$1"
PARAM_ASK="$2"
PARAM_TEST="$3"

# Install service from source - compile
install_from_source() {

	echo "Install service from source"

	# Install SHM driver libs
	install_shm_libs
	# Check installation result
	if [ "$?" -ne "0" ]
	then
		echo "Library instalation failed - check logs"
		return 1
	fi

	# Compile service
	compile_service
	# Check compilation result
	if [ "$?" -ne "0" ]
	then
		echo "Service compilation failed - check logs"
		return 1
	fi

	return 0
}

compile_service() {

	echo "Service compilation"

	# Create build directory
	cd openNetworkHMI_service/
	if [ ! -d build/ ]
	then
	    mkdir build
	fi
	cd build

	# Generate makefile
	if [ $ONH_TEST -eq 1 ]
	then
		cmake -DWithTest=true ..
	else
		cmake ..
	fi
	
	# Compile
	make

	cd ../

	# Check if openNetworkHMI is compiled
	if [ ! -f build/openNetworkHMI ]
	then
		echo "openNetworkHMI service is not compiled - Check compilation logs"
		return 1
	fi

	if [ $ONH_TEST -eq 1 ]
	then
		# Check if openNetworkHMI test program is compiled
		if [ ! -f build/test/tests/openNetworkHMI_test ]
		then
			echo "openNetworkHMI test app is not compiled - Check compilation logs"
			return 1
		fi

		# Check if test server 1 is compiled
		if [ ! -f build/test/test_server1/onh_test_server1 ]
		then
			echo "openNetworkHMI test server 1 app is not compiled - Check compilation logs"
			return 1
		fi

		# Check if test server 2 is compiled
		if [ ! -f build/test/test_server2/onh_test_server2 ]
		then
			echo "openNetworkHMI test server 2 app is not compiled - Check compilation logs"
			return 1
		fi
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

install_shm_libs() {

	echo "Libraries compilation"

	# Compile SHM driver libraries
	cd openNetworkHMI_service/library/
	if [ ! -d build/ ]
	then
	    mkdir build
	fi
	cd build

	# Generate makefile
	if [ $ONH_TEST -eq 1 ]
	then
		cmake -DWithTest=true ..
	else
		cmake ..
	fi
	
	# Compile
	make

	# Check if library is compiled
	if [ ! -f libonhSHMc/libonhSHMc.a ]
	then
		echo "Library libonhSHMc is not compiled - Check compilation logs"
		return 1
	fi

	# Check if library is compiled
	if [ ! -f libonhSHMcpp/libonhSHMcpp.a ]
	then
		echo "Library libonhSHMcpp is not compiled - Check compilation logs"
		return 1
	fi

	# Install library
	sudo make install

	cd ../

	# Check installation
	if [ ! -d /usr/local/include/onhSHMc ]
	then
	    echo "libonhSHMc not installed - check installation logs"
	    return 1
	fi

	# Check installation
	if [ ! -d /usr/local/include/onhSHMcpp ]
	then
	    echo "libonhSHMcpp not installed - check installation logs"
	    return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

onh_db_install() {

	echo "DB structure installation"

	read -p 'Username: ' dbUser
	echo -n "Password: "
	stty -echo
	read dbPass
	stty echo
	echo
	
	# Prepare DB
	mysql -u $dbUser -p$dbPass < openNetworkHMI_web/dbSchema/schema.sql
	if [ "$?" -ne "0" ]
	then
		echo "DB schema creation error - see logs"
		return 1
	fi

	# Prepare service config file
	echo "Prepare openNetworkHMI service db configuration file"
	echo "openNetworkHMI_DB\nlocalhost\n$dbUser\n$dbPass" > openNetworkHMI_service/build/dbConn.conf

	# Prepare web app config file
	echo "Prepare openNetworkHMI web app configuration file"
	echo "DATABASE_URL=mysql://$dbUser:$dbPass@127.0.0.1:3306/openNetworkHMI_DB" > openNetworkHMI_web/.env.local

	return 0
}

onh_web_install() {

	# Check if composer is installed
	if [ ! -f /usr/local/bin/composer ]
	then
		echo "Composer is not installed - Check installation"
		return 1
	fi

	echo "Composer install"
	cd openNetworkHMI_web
	composer install
	if [ "$?" -ne "0" ]
	then
		echo "Composer installation error - see logs"
		return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	# Install virtual host?
	defVhost="Y"
	if [ $ONH_ASK -eq 1 ]
	then
		read -p "Do you want to install default virtual host? [Y]: " defVhost
		defVhost=${defVhost:-Y}
	fi
	
	if [ "$defVhost" = "Y" ] || [ "$defVhost" = "y" ]
	then

		# Check if not installed
		if [ ! -d /var/www/openNetworkHMI ]
		then
			# Create symlink in /var/www/
			echo "Create symlink in /var/www to openNetworkHMI web application"
			sudo ln -s "$BASEDIR"/openNetworkHMI_web /var/www/openNetworkHMI
		else
			echo "Symlink /var/www/openNetworkHMI already exist"
		fi

		# Check if not installed
		if [ ! -f /etc/apache2/sites-available/openNetworkHMI.conf ]
		then
			# Copy default virtual host file to apache
			echo "Copy virtualhost file to /etc/apache2/sites-available/"
			sudo cp openNetworkHMI_web/distFiles/vhost/openNetworkHMI.conf /etc/apache2/sites-available/
		else
			echo "Virtualhost file already exist"
		fi

		# Check if not installed
		if [ ! -f /etc/apache2/sites-enabled/openNetworkHMI.conf ]
		then
			# Activate configuration
			echo "Activate virtual host"
			sudo a2ensite openNetworkHMI.conf
			if [ "$?" -ne "0" ]
			then
				echo "Activation of the virtual host failed - see logs"
				return 1
			fi
			# Reastart apache
			echo "Restart apache"
			sudo service apache2 reload
			if [ "$?" -ne "0" ]
			then
				echo "Apache2 restart failed - see logs"
				return 1
			fi

			echo "---------------------------------------------------"
			echo "Put this line:"
			echo "127.0.0.1	openNetworkHMI.local"
			echo "into /etc/hosts"
			echo "---------------------------------------------------"
		else
			echo "Virtualhost already activated"
		fi

	else
		echo "Create virtual host manually in apache server"
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

onh_web_paths_update() {

	cd openNetworkHMI_web/bin

	# Update application paths
	echo "Update web app paths..."

	if [ $ONH_ASK -eq 1 ]
	then
		php console app:update-paths --ask=yes
	else
		php console app:update-paths
	fi

	if [ "$?" -ne "0" ]
	then
		echo "openNetworkHMI update paths failed - see logs"
		return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

onh_create_sudoers() {

	cd openNetworkHMI_web/bin

	# Create sudoers premission file
	echo "Create sudoers premissions file..."
	php console app:generate-sudoers
	if [ "$?" -ne "0" ]
	then
		echo "openNetworkHMI generate sudoers failed - see logs"
		return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	# Copy generated file to /etc/sudoers.d/
	echo "Copy sudoers premissions file to /etc/sudoers.d/"
	sudo cp openNetworkHMI_web/distFiles/sudoers/openNetworkHMI_premissions /etc/sudoers.d/

	return 0
}

onh_create_systemd() {

	cd openNetworkHMI_web/bin

	# Create sudoers premission file
	echo "Create systemd service file..."
	php console app:generate-systemd
	if [ "$?" -ne "0" ]
	then
		echo "openNetworkHMI generate systemd failed - see logs"
		return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	# Copy generated file to /etc/systemd/system/
	echo "Copy systemd file to /etc/systemd/system/"
	sudo cp openNetworkHMI_web/distFiles/systemd/openNetworkHMI.service /etc/systemd/system/
	sudo systemctl daemon-reload

	return 0
}

onh_create_test_env() {

	echo "Test DB structure installation"

	read -p 'Username: ' dbUser
	echo -n "Password: "
	stty -echo
	read dbPass
	stty echo
	echo

	# Check if bin directory exist
	if [ ! -d tests/bin/ ]
	then
	    mkdir tests/bin
	fi

	# Check if bin/onh directory exist
	if [ ! -d tests/bin/onh ]
	then
	    mkdir tests/bin/onh
	fi
	
	# Prepare service config file
	echo "Prepare openNetworkHMI test service db configuration file"
	echo "openNetworkHMI_DB_test\nlocalhost\n$dbUser\n$dbPass" > tests/bin/onh/dbConn.conf

	# Prepare web app config file
	echo "Prepare openNetworkHMI test web app configuration file"
	echo "DATABASE_URL=mysql://$dbUser:$dbPass@127.0.0.1:3306/openNetworkHMI_DB_test" > openNetworkHMI_web/.env.test.local

	cd openNetworkHMI_web/bin

	# Create sudoers premission file
	echo "Create test DB sql file..."

	if [ $ONH_ASK -eq 1 ]
	then
		php console app:generate-test-sql --ask=yes
	else
		php console app:generate-test-sql
	fi

	if [ "$?" -ne "0" ]
	then
		echo "openNetworkHMI generate test DB sql file failed - see logs"
		return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	# Prepare DB
	echo "Create test DB..."
	mysql -u $dbUser -p$dbPass < openNetworkHMI_web/distFiles/testDB/db.sql
	if [ "$?" -ne "0" ]
	then
		echo "Test DB schema creation error - see logs"
		return 1
	fi

	return 0
}

attach_submodules_head() {

	# Attach head?
	if [ $BRANCH_CHECKOUT -eq 1 ]
	then
		
		cd openNetworkHMI_service
		echo "Checkout openNetworkHMI_service to $BRANCH"
		git checkout $BRANCH
		if [ "$?" -ne "0" ]
		then
			echo "openNetworkHMI service checkout to $BRANCH failed - see logs"
			return 1
		fi

		cd ../openNetworkHMI_web
		echo "Checkout openNetworkHMI_web to $BRANCH"
		git checkout $BRANCH
		if [ "$?" -ne "0" ]
		then
			echo "openNetworkHMI web app checkout to $BRANCH failed - see logs"
			return 1
		fi

		# Back to the main directory
		cd $BASEDIR

	fi

	return 0
}

check_params() {

	# Checkout select
	if [ -z "$PARAM_CHECKOUT" ]
	then
		echo "Submodules checkout ON"
	else
		if [ "$PARAM_CHECKOUT" = "checkoutOFF" ]
		then
			echo "Submodules checkout OFF"
			BRANCH_CHECKOUT=0
		elif [ "$PARAM_CHECKOUT" = "checkoutON" ]
		then
			echo "Submodules checkout ON"
			BRANCH_CHECKOUT=1
		else
			echo "Invalid Checkout config parameter"
			return 1
		fi
	fi

	# Ask select
	if [ -z "$PARAM_ASK" ]
	then
    	echo "No asking mode"
	else
		if [ "$PARAM_ASK" = "ask" ]
		then
			echo "Asking mode ON"
			ONH_ASK=1
		elif [ "$PARAM_ASK" = "askOFF" ]
		then
			echo "Asking mode OFF"
			ONH_ASK=0
		else
			echo "Invalid ASK parameter"
			return 1
		fi
	fi

	# Tests select
	if [ -z "$PARAM_TEST" ]
	then
    	echo "No test build"
	else
		if [ "$PARAM_TEST" = "test" ]
		then
			echo "Test build ON"
			ONH_TEST=1
		elif [ "$PARAM_TEST" = "testOFF" ]
		then
			echo "Test build OFF"
			ONH_TEST=0
		else
			echo "Invalid TEST parameter"
			return 1
		fi
	fi

	return 0
}

# Main installation function
onh_install() {

	check_params
	if [ "$?" -ne "0" ]
	then
		echo "Check params failed - check logs"
		return 1
	fi

	attach_submodules_head
	if [ "$?" -ne "0" ]
	then
		echo "Git submodules checkout failed - check logs"
		return 1
	fi

	install_from_source
	if [ "$?" -ne "0" ]
	then
		echo "Service installation failed - check logs"
		return 1
	fi

	# Install DB structure
	onh_db_install
	if [ "$?" -ne "0" ]
	then
		echo "DB installation failed - check logs"
		return 1
	fi

	# Install web app
	onh_web_install
	if [ "$?" -ne "0" ]
	then
		echo "Web app installation failed - check logs"
		return 1
	fi

	# Update web app paths
	onh_web_paths_update
	if [ "$?" -ne "0" ]
	then
		echo "Web app path update failed - check logs"
		return 1
	fi

	# Create sudoers premissions for web app
	onh_create_sudoers
	if [ "$?" -ne "0" ]
	then
		echo "Create sudoers premissions failed - check logs"
		return 1
	fi

	# Create systemd service file
	onh_create_systemd
	if [ "$?" -ne "0" ]
	then
		echo "Create systemd service failed - check logs"
		return 1
	fi

	# Create test environment
	onh_create_test_env
	if [ "$?" -ne "0" ]
	then
		echo "Create test environment failed - check logs"
		return 1
	fi

	echo "Instalation finished"
}

onh_install
