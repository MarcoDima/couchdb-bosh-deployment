#!/bin/bash

### shutting down one of the instances ###

bosh stop couchdb3/$1 --hard -d couchdb-service-broker -e vbox -n

exit 0
