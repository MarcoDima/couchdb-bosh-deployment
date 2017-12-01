#!/bin/bash

### shutting down one of the instances ###

bosh stop $1 --hard -d couchdb-service-broker -e vbox -n

exit 0
