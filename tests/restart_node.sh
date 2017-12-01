#!/bin/bash

### restarting one of the instances ###

bosh start $1 -d couchdb-service-broker -e vbox -n

exit 0
