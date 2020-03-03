#!/bin/sh

# Run all openNetworkHMI unit tests with report

cd ../openNetworkHMI_web

./bin/phpunit --testsuite unit --coverage-html ../tests/reports/
