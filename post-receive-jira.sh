#!/bin/bash

REAL_PATH="$(readlink ${BASH_SOURCE[0]})"
if [ -z $REAL_PATH ]; then
    REAL_PATH=${BASH_SOURCE[0]}
fi
RUNDIR="$( cd "$( dirname "$REAL_PATH" )" && pwd )"
LINKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GIT=$(echo $LINKDIR | grep -oh '[^/]*\.git' )


if [ ! -f $RUNDIR/config.sh ]; then
    echo Config file required. See config.sample.sh
    exit -1
fi

source $RUNDIR/config.sh
JIRA_REFS_FILE=$RUNDIR/jira_refs.txt

touch $JIRA_REFS_FILE

#ignored, replaced on 20191128 with generic pattern
JIRA_REGEXP=()
for JIRA_PROJECT in $JIRA_PROJECTS; do
    JIRA_REGEXP+=(-e "$JIRA_PROJECT-[0-9]*")
done

function log() {
    TYPE=$1
    if [ "$TYPE" = "error" ]; then
        echo $*
    fi
}

# this updates the jira customField with new msg which is added first
function updateJira() {
    #params
    ISSUE=$1
    MSG=$2
    HASH=$3
    DATE=$4

    #fetch the id of the custom field given its name
    CUSTOM_FIELD_ID=$(curl -s -u $AUTH -H "Content-Type: application/json" -X GET $JIRA_URL/rest/api/2/issue/$ISSUE/editmeta | jq ".fields[] | select(.name | contains(\"$CUSTOM_FIELD_NAME\")) .fieldId" | sed 's/^"//' | sed 's/"$//' )

    if [ -z $CUSTOM_FIELD_ID ]; then
        log error "Could not find jira fieldId for $ISSUE/$CUSTOM_FIELD_NAME, check jira config"
        return
    else    
        log info "fieldId => $CUSTOM_FIELD_ID"
    fi

    #fetch the old value of the custom field
    VALUE=$(curl -s -u $AUTH -H "Content-Type: application/json" -X GET $JIRA_URL/rest/api/2/issue/$ISSUE?fields=$CUSTOM_FIELD_ID | jq  ".fields.$CUSTOM_FIELD_ID" | sed 's/^"//' | sed 's/"$//' )

    UPDATE=1
    if [ "x$VALUE" == "xnull" ]; then
        NVALUE=$MSG
    else
        echo -n $VALUE | grep -q $HASH
        if [ $? -eq 0 ]; then
            UPDATE=0
        else
            NVALUE="$MSG\n$VALUE"
        fi
    fi

    CNT=$(echo -n $VALUE | wc -c)
    if [[ $CNT -ge 32000 ]]; then
        UPDATE=0
        echo Jira issue $JIRA_REF message is too long: $CNT
        return
    fi

    log info Msg: $NVALUE

    grep -q $JIRA_REF $JIRA_REFS_FILE
    if [ $? -ne 0 ]; then
        echo $JIRA_REF >> $JIRA_REFS_FILE
    fi

    if [ $UPDATE -eq 1 ]; then
        curl -s -u $AUTH -H "Content-Type: application/json" -X PUT --data "{\"fields\": { \"$CUSTOM_FIELD_ID\":\"$NVALUE\" }}" $JIRA_URL/rest/api/2/issue/$ISSUE
        echo Jira issue $JIRA_REF updated for $HASH/$DATE
    else
        echo Jira issue $JIRA_REF already contains reference to $HASH/$DATE
    fi
}

function getCommitMsg() {
    REV=$1

    #BRANCH=$(git rev-parse --symbolic --abbrev-ref $REV)
    #BRANCH=$(git log -1 --pretty=%D $REV | cut -f1 -d',')
    BRANCH=$(git name-rev --name-only $REV | cut -f1 -d'~')
    JIRA_REFS=$(git log -1 --pretty=%s $REV | grep -oh "[A-Z]\{3,10\}-[0-9]\{1,5\}")

    if [ $? -eq 0 ]; then
        #found jira message       
        HASH=$(git log -1 --pretty="%h" $REV )                                                  
        FILES=$(git diff-tree -r --name-only --no-commit-id $REV | sed 's/^/- /' | sed 's/$/\\n/g' | tr -d '\n')
        LOG=$(git log -1 --pretty="*%h/$BRANCH* - %cN on %cd\n%s" --date=short $REV )
        DATE=$(git log -1 --pretty="%cd" --date=short $REV)

        #echo LOG: $LOG
        #echo FILES: $FILES

        MSG="$GIT $LOG\n$FILES\n----\n"

        #echo MSG: $MSG

        # MSG=$(echo -n $MSG | sed 's/$/#/g' | tr -d '\n')
        for JIRA_REF in $JIRA_REFS; do
            updateJira $JIRA_REF "$MSG" $HASH $DATE
        done
    else
        echo No JIRA references found in commit message
    fi
}

if [[ "$1" == "manual" ]] && [[ -n "$2" ]]; then
    getCommitMsg $2
else
    while read OLDREV NEWREV REFNAME
    do
        echo Executing with $OLDREV $NEWREV $REFNAME
        if [[ $REFNAME =~ refs/tags/.* ]] || [[ $REFNAME =~ refs/remotes/.* ]]; then
            echo "Detected tagging or branching operation, will do nothing"
            exit 0
        fi
        if expr "$OLDREV" : '0*$' >/dev/null; then
            # list everything reachable from NEWREV but not any heads
            REVLIST=$(git rev-list $(git for-each-ref --format='%(REFNAME)' refs/heads/* | sed 's/^/\^/') "$NEWREV")
            echo "This list everything from the begining, skipping"
            exit 0
        else
            REVLIST=$(git rev-list "$OLDREV..$NEWREV")
        fi

        for REV in $REVLIST; do
            getCommitMsg $REV
        done
    done
fi
