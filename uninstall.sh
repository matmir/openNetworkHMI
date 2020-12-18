#!/bin/sh

# openNetworkHMI uninstallation script

# Change directory to the install script
SCRIPTDIR=$(dirname $0)
cd $SCRIPTDIR

# Base script directory
BASEDIR=$(pwd)

# Clean sources compilation
clean_sources() {

	echo "Clean source compilation"

	# Uninstall SHM driver libs
	clean_shm_libs
	# Check result
	if [ "$?" -ne "0" ]
	then
		echo "Library cleaning failed - check logs"
		return 1
	fi

	# Clean service
	clean_service
	# Check result
	if [ "$?" -ne "0" ]
	then
		echo "Services cleaning failed - check logs"
		return 1
	fi

	return 0
}

clean_service() {

	echo "Service cleaning"

	# Clean services
	cd openNetworkHMI_service/
	sudo rm -r build/

	# Check if openNetworkHMI is cleared
	if [ -d build ]
	then
		echo "openNetworkHMI is not cleared - Check logs"
		return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

clean_shm_libs() {

	echo "Libs clean"

	# Clean SHM driver c libs
	cd openNetworkHMI_service/library/libonhSHMc
	sudo rm -r build/

	# Check if library is cleaned
	if [ -d build ]
	then
		echo "Library libonhSHMc is not cleaned - Check logs"
		return 1
	fi

	# Uninstall library
	sudo rm -r /usr/local/include/onhSHMc
	sudo rm /usr/local/lib/onhSHMc.a

	# Check uninstallation
	if [ -d /usr/local/include/onhSHMc ] || [ -f /usr/local/lib/onhSHMc.a ]
	then
	    echo "libonhSHMc not uninstalled - check logs"
	    return 1
	fi

	# Clean SHM driver c++ libs
	cd ../libonhSHMcpp
	sudo rm -r build/

	# Check if library is cleaned
	if [ -d build ]
	then
		echo "Library libonhSHMcpp is not cleaned - Check logs"
		return 1
	fi

	# Uninstall library
	sudo rm -r /usr/local/include/onhSHMcpp
	sudo rm /usr/local/lib/onhSHMcpp.a

	# Check uninstallation
	if [ -d /usr/local/include/onhSHMcpp ] || [ -f /usr/local/lib/onhSHMcpp.a ]
	then
	    echo "libonhSHMcpp not uninstalled - check logs"
	    return 1
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

onh_db_uninstall() {

	echo "DB uninstallation"

	read -p 'Username: ' dbUser
	echo -n "Password: "
	stty -echo
	read dbPass
	stty echo
	echo
	
	# Drop DB
	mysql -u $dbUser -p$dbPass -e "DROP DATABASE IF EXISTS openNetworkHMI_DB;"
	if [ "$?" -ne "0" ]
	then
		echo "openNetworkHMI_DB DB drop error - see logs"
		return 1
	fi
	mysql -u $dbUser -p$dbPass -e "DROP DATABASE IF EXISTS openNetworkHMI_DB_test;"
	if [ "$?" -ne "0" ]
	then
		echo "openNetworkHMI_DB_test DB drop error - see logs"
		return 1
	fi

	# Remove web app config file
	echo "Remove openNetworkHMI web app configuration file"
	rm -f openNetworkHMI_web/.env.local

	return 0
}

onh_web_uninstall() {

	echo "Remove openNetworkHMI vendor directory"
	sudo rm -rf openNetworkHMI_web/vendor/

	# Create symlink in /var/www/
	echo "Remove openNetworkHMI symlink from /var/www"
	sudo rm -f /var/www/openNetworkHMI

	# Check if installed
	if [ -f /etc/apache2/sites-enabled/openNetworkHMI.conf ]
	then
		# Remove configuration
		echo "Remove virtual host"
		sudo rm /etc/apache2/sites-enabled/openNetworkHMI.conf
		sudo rm /etc/apache2/sites-available/openNetworkHMI.conf

		# Reastart apache
		echo "Restart apache"
		sudo service apache2 reload
		if [ "$?" -ne "0" ]
		then
			echo "Apache2 restart failed - see logs"
			return 1
		fi

		echo "---------------------------------------------------"
		echo "Remove this line:"
		echo "127.0.0.1	openNetworkHMI.local"
		echo "from /etc/hosts"
		echo "---------------------------------------------------"
	fi

	# Back to the main directory
	cd $BASEDIR

	return 0
}

onh_remove_sudoers() {

	# Check if installed
	if [ -f /etc/sudoers.d/openNetworkHMI_premissions ]
	then

		echo "Remove sudoers premissions file from /etc/sudoers.d/"
		sudo rm /etc/sudoers.d/openNetworkHMI_premissions
	fi

	return 0
}

onh_remove_systemd() {

	# Check if installed
	if [ -f /etc/systemd/system/openNetworkHMI.service ]
	then
		sudo systemctl stop openNetworkHMI.service
		sudo systemctl disable openNetworkHMI.service
		echo "Remove systemd file from /etc/systemd/system/"
		sudo rm /etc/systemd/system/openNetworkHMI.service
		sudo systemctl daemon-reload
	fi

	return 0
}

onh_remove_test_env() {

	# Remove bin directory
	rm -rf tests/bin

	# Prepare web app config file
	echo "Remove openNetworkHMI test web app configuration file"
	rm -f openNetworkHMI_web/.env.test.local

	return 0
}

# Main installation function
onh_uninstall() {

	clean_sources
	if [ "$?" -ne "0" ]
	then
		echo "Service uninstallation failed - check logs"
		return 1
	fi

	# Uninstall DB
	onh_db_uninstall
	if [ "$?" -ne "0" ]
	then
		echo "DB uninstallation failed - check logs"
		return 1
	fi

	# Uninstall web app
	onh_web_uninstall
	if [ "$?" -ne "0" ]
	then
		echo "Web app uninstallation failed - check logs"
		return 1
	fi

	# Remove sudoers premissions for web app
	onh_remove_sudoers
	if [ "$?" -ne "0" ]
	then
		echo "Remove sudoers premissions failed - check logs"
		return 1
	fi

	# Remove systemd service file
	onh_remove_systemd
	if [ "$?" -ne "0" ]
	then
		echo "Remove systemd service failed - check logs"
		return 1
	fi

	# Remove test environment
	onh_remove_test_env
	if [ "$?" -ne "0" ]
	then
		echo "Remove test environment failed - check logs"
		return 1
	fi

	echo "Uninstalation finished"
}

onh_uninstall
