#!/bin/sh

# Change directory to the script directory
SCRIPTDIR=$(dirname $0)
cd $SCRIPTDIR

# Run all openNetworkHMI unit tests with report

cd ../openNetworkHMI_web

XDEBUG_MODE=coverage php ./vendor/bin/phpunit --testsuite unit --coverage-html ../tests/reports/
