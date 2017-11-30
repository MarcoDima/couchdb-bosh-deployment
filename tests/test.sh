#!/bin/bash

############################# Testing HAproxy On CouchDB Cluster #############################

COUCHDB_USER=admin
COUCHDB_PWD=admin
export RUNNING_VM=$(bosh -e vbox -d couchdb-service-broker vms | awk 'END{print $4}')

COUCHDB_SAY="CouchDB RESPONSE\t==>\t"
export PORT=5984
DB="test"
FAIL_DB="after-failure"
LOG_DIR=/home/dima/couchdb.log 
HTTP_STATUS_OK=200
HTTP_STATUS_CREATED=201
HTTP_STATUS_ACCEPTED=202
HTTP_STATUS_NOT_FOUND=404
HTTP_STATUS_FORBIDDEN=403
HTTP_STATUS_BAD_REQUEST=400
HTTP_STATUS_UNAUTHORIZED=401
HTTP_STATUS_INTERNAL_SERVER_ERROR=500
RAND_NUM=$(shuf -i3-5 -n1)

function assertOk () {
    if [ $1 == $HTTP_STATUS_OK ];then
        echo -e "Successfully got database\n"
    else
        echo "Could not get the database"
        echo "Exiting ..."
        exit 1
    fi
}

function assertDeleted () {
    if [ $1 == $HTTP_STATUS_ACCEPTED ];then
        echo -e "Deleted database\n"
    else
        echo "Could not delete the database"
        echo "Exiting ..."
        exit 1
    fi
}

function check_all_instances_running () {
    for i in `seq 3 6`
        do
        echo "Instance 10.244.0.$i:"
        PROC_STATE=$(bosh -e vbox instances | head -$i | awk '{print $2}')
        if [ ! $PROC == running ];then
            echo "Expected 10.244.0.$i to be \"running\" but did not match."
            exit 1
        else
        echo "OK"
        fi
        done
    echo "All instances are running"
}
echo " "
echo " "
echo " "
echo -e "\t###########################################################"
echo -e "\t#                                                         #"
echo -e "\t#\tStarting test on CouchDB Cluster under haproxy    #"
echo -e "\t#\t        RUNNING ON: $RUNNING_VM                     #\n"
echo -e "\t#                                                         #"
echo -e "\t###########################################################\n"

echo -e "\t###########################################################"
echo -e "\t\tCreating database $DB (before node failure)"
echo -e "\t###########################################################\n"

echo "Creating db ..."
#REQ_STATUS=$(curl -I -X PUT http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$DB | head -1 | awk '{print $2}')
#echo $REQ_STATUS
#assertCreated $REQ_STATUS
echo -n -e $COUCHDB_SAY
curl -X PUT http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$DB
echo "Getting database from 10.244.0.$RAND_NUM"
REQ_STATUS=$(curl -I -X GET http://$COUCHDB_USER:$COUCHDB_PWD@10.244.0.$RAND_NUM:$PORT/$DB | head -1 | awk '{print $2}')
assertOk $REQ_STATUS

echo -e "\t#############################################"
echo -e "\t\tShutting down node on cluster "
echo -e "\t#############################################\n"

echo "Shutting down ..."
NUM=$(shuf -i0-2 -n1)

IP_ADDRESS=$(bosh -e vbox instances | head -$NUM | tail -1 | awk '{print $4}')

./fail_node.sh $NUM > $LOG_DIR

sleep 10
echo -e "\n OK \n"

echo -e "\t######################################################"
echo -e "\t\tChecking number of nodes in cluster "
echo -e "\t######################################################\n"

for i in `seq 3 5`;
do
    echo "Checking cluster from 10.244.0.$i"
    curl -X GET http://$COUCHDB_USER:$COUCHDB_PWD@10.244.0.$i:$PORT/_membership
    if [ "$?" -ne 0 ]; then
        echo "This node failed and is no more reachable "
    fi
    echo " "
done

echo -e "\t#################################################################"
echo -e "\t\tCreating database $FAIL_DB (after node failure) "
echo -e "\t#################################################################\n"

echo "Creating db ..."
#REQ_STATUS=$(curl -I -X PUT http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$FAIL_DB | head -1 | awk '{print $2}')
echo -n -e $COUCHDB_SAY
curl -X PUT http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$FAIL_DB
#assertCreated $REQ_STATUS

echo -e "\n     ### Performing some requests to check forwarding on haproxy ... ###\n"

echo "Getting db ... "
REQ_STATUS=$(curl -I -X GET http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$FAIL_DB | head -1 | awk '{print $2}')
assertOk $REQ_STATUS

echo -e "\nWriting document in db $FAIL_DB ...\n"
#REQ_STATUS=$(curl -I -X PUT http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$FAIL_DB/001 -d '{"name": "Marco"}' | head -1 | awk '{print $2}')
echo -n -e $COUCHDB_SAY
curl -X PUT -H "Content-type:application/json" http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$FAIL_DB/001 -d '{}'
#assertCreated $REQ_STATUS

echo -e "\nGetting document with id=001 in db $FAIL_DB ...\n"
REQ_STATUS=$(curl -I -X GET http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$FAIL_DB/001 | head -1 | awk '{print $2}')
assertOk $REQ_STATUS

echo -e "\t##############################################"
echo -e "\t\tRecreate vm after failure      "
echo -e "\t##############################################\n"

echo "Recreating vm ..."
./restart_node.sh $NUM > $LOG_DIR 

sleep 10

echo -e "\nChecking all instances are now running ...\n"
check_all_instances_running

echo -e "\t################################################################################"
echo -e "\t\tChecking all changes after failure were restored in failure node    "
echo -e "\t################################################################################\n"

echo "Getting database $FAIL_DB from $IP_ADDRESS ..."
REQ_STATUS=$(curl -I -X GET http://$COUCHDB_USER:$COUCHDB_PWD@$IP_ADDRESS:$PORT/$FAIL_DB | head -1 | awk '{print $2}')
assertOk $REQ_STATUS

echo -e "\nGetting document with id=001 from $IP_ADDRESS ..."
REQ_STATUS=$(curl -I -X GET http://$COUCHDB_USER:$COUCHDB_PWD@$IP_ADDRESS:$PORT/$FAIL_DB/001 | head -1 | awk '{print $2}')
assertOk $REQ_STATUS

echo -e "All changes are present in previously failed node\n"

echo -e "\t#################################################"
echo -e  "\t\tDeleting databases from test "
echo -e "\t#################################################\n"

curl -X DELETE http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$DB
curl -X DELETE http://$COUCHDB_USER:$COUCHDB_PWD@$RUNNING_VM:$PORT/$FAIL_DB

echo "Finishing ..."
exit 0
