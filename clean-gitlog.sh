#!/bin/bash

RUNDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $RUNDIR/config.sh ]; then
    echo Config file required. See config.sample.sh
    exit -1
fi

source $RUNDIR/config.sh
JIRA_REFS_FILE=$RUNDIR/jira_refs.txt

CUSTOM_FIELD_ID=$(curl -s -u $AUTH -H "Content-Type: application/json" -X GET $JIRA_URL/rest/api/2/issue/DPSN-8826/editmeta | jq ".fields[] | select(.name | contains(\"$CUSTOM_FIELD_NAME\")) .fieldId" | sed 's/^"//' | sed 's/"$//' )

if [ -z $CUSTOM_FIELD_ID ]; then
    echo "Could not find jira fieldId for $CUSTOM_FIELD_NAME, check jira config"
    exit -1
else    
    echo "fieldId => $CUSTOM_FIELD_ID"
fi

cat $JIRA_REFS_FILE | while read JIRA_REF; do
    curl -s -u $AUTH -H "Content-Type: application/json" -X PUT --data "{\"fields\": { \"$CUSTOM_FIELD_ID\":\"\" }}" $JIRA_URL/rest/api/2/issue/$JIRA_REF
    echo Jira issue $JIRA_REF cleaned
done