openNetworkHMI
=======

Web based framework for creating HMI interfaces.

INSTALL
=======

	git clone --recursive https://github.com/matmir/openNetworkHMI.git
	cd openNetworkHMI/
	./install.sh

Additional install parameters:

	./install.sh [BRANCH_CHECKOUT] [ONH_ASK] [ONH_TEST]
	
	BRANCH_CHECKOUT - checkout submodules to the main repo branch.
	                  Values: "checkoutON" or "checkoutOFF" - default "checkoutON".
	ONH_ASK         - install with additional user questions.
	                  Values: "ask" or "askOFF" - default "askOFF".
	ONH_TEST        - compile tests.
	                  Values: "test" or "testOFF" - default "testOFF".

Install develop version with ask mode and tests:

	git clone --recursive https://github.com/matmir/openNetworkHMI.git
	cd openNetworkHMI/
	git checkout develop
	./install.sh checkoutON ask test

Project site: https://opennetworkhmi.net

License
=======

Software is licensed on GPLv3 license. Library for Shared memory driver is available on BSD license.