#!/bin/sh

# openNetworkHMI installation script

# Change directory to the install script
SCRIPTDIR=$(dirname $0)
cd $SCRIPTDIR

# Base script directory
BASEDIR=$(pwd)

# Install service from source - compile
install_from_source() {

	echo "Install service from source"

	# Check MariaDB lib
	if [ ! -d /usr/include/mariadb ]
	then
	    echo "Missing libmariadb-dev"
	    return 1
	fi

	# Check modbus lib
	if [ ! -d /usr/local/include/modbus ]
	then
	    echo "Missing libmodbus"
	    return 1
	fi

	# Check gtest lib
	if [ ! -d /usr/local/include/gtest ]
	then
	    echo "Missing googletest"
	    return 1
	fi

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

	# Compile services
	cd openNetworkHMI_service/
	make release

	# Check if openNetworkHMI is compiled
	if [ ! -f build/app/openNetworkHMI ]
	then
		echo "openNetworkHMI service is not compiled - Check compilation logs"
		return 1
	fi

	# Check if openNetworkHMI test program is compiled
	if [ ! -f test/tests/build/app/openNetworkHMI_test ]
	then
		echo "openNetworkHMI test app is not compiled - Check compilation logs"
		return 1
	fi

	# Check if test server 1 is compiled
	if [ ! -f test/test_server1/build/app/onh_test_server1 ]
	then
		echo "openNetworkHMI test server 1 app is not compiled - Check compilation logs"
		return 1
	fi

	# Check if test server 2 is compiled
	if [ ! -f test/test_server2/build/app/onh_test_server2 ]
	then
		echo "openNetworkHMI test server 1 app is not compiled - Check compilation logs"
		return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

install_shm_libs() {

	echo "Libs compilation"

	# Compile SHM driver c libs
	cd openNetworkHMI_service/library/libonhSHMc
	make release

	# Check if library is compiled
	if [ ! -f build/lib/libonhSHMc.a ]
	then
		echo "Library libonhSHMc is not compiled - Check compilation logs"
		return 1
	fi

	# Install library
	sudo make install

	# Check installation
	if [ ! -d /usr/local/include/onhSHMc ]
	then
	    echo "libonhSHMc not installed - check installation logs"
	    return 1
	fi

	# Compile SHM driver c++ libs
	cd ../libonhSHMcpp
	make release

	# Check if library is compiled
	if [ ! -f build/lib/libonhSHMcpp.a ]
	then
		echo "Library libonhSHMcpp is not compiled - Check compilation logs"
		return 1
	fi

	# Install library
	sudo make install

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
	echo "openNetworkHMI_DB\nlocalhost\n$dbUser\n$dbPass" > openNetworkHMI_service/build/app/dbConn.conf

	# Prepare web app config file
	echo "Prepare openNetworkHMI web app configuration file"
	echo "DATABASE_URL=mysql://$dbUser:$dbPass@127.0.0.1:3306/openNetworkHMI_DB" > openNetworkHMI_web/.env.local

	return 0
}

onh_web_install() {

	# Install with composer on this machine?
	read -p "Do you want to run composer on this machine? [Y]: " runComposer
	runComposer=${runComposer:-Y}
	if [ "$runComposer" = "Y" ] || [ "$runComposer" = "y" ]
	then

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

	else
		echo "Run composer install on other machine and copy vendor catalog into openNetworkHMI_web directory"
		read -p "Press Enter when finished..." entWait
	fi

	# Back to the main directory
	cd $BASEDIR

	# Install virtual host?
	read -p "Do you want to install default virtual host? [Y]: " defVhost
	defVhost=${defVhost:-Y}
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
	php console app:update-paths
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
	php console app:generate-test-sql
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

	cd openNetworkHMI_service
	if [ ! -z "$(git status | grep 'HEAD detached at*')" ]; then
		echo "Checkout openNetworkHMI_service to master"
		git checkout master
		if [ "$?" -ne "0" ]
		then
			echo "openNetworkHMI service checkout to master failed - see logs"
			return 1
		fi
	fi

	cd ../openNetworkHMI_web
	if [ ! -z "$(git status | grep 'HEAD detached at*')" ]; then
		echo "Checkout openNetworkHMI_web to master"
		git checkout master
		if [ "$?" -ne "0" ]
		then
			echo "openNetworkHMI web app checkout to master failed - see logs"
			return 1
		fi
	fi
	
	# Back to the main directory
	cd $BASEDIR

	return 0
}

# Main installation function
onh_install() {

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
