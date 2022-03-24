#!/usr/bin/env bash

menu() {
    echo "********************automation*****************************"
    echo "execute the script with 3 arguments: ticket id, release id, product id and commit id"
    echo "e.g ./automation.sh XXX-1111 1.1.1 product-id ccccc"
    echo "********************automation*****************************"
}


STEPS=(BRANCH_CHECKED_OUT PR_CREATED JOB_CREATED JOB_STATUS PR_STATUS)


PROJECT_GIT="<repo>"
PROJECT_API_URL="pr_url"

ISSUE_ID=''
APP_VERSION=''
PRODUCT_ID=''
COMMIT_ID=''

BIT_PASS="<app_pass>"
BIT_USER="<user>"
BIT_AUTH="<basic_auth>"

PROCESS_DIR=".process"
PROCESS_FILE=""
start() {
    ISSUE_ID=$1
    APP_VERSION=$2
    PRODUCT_ID=$3
    COMMIT_ID=$4
    echo "$ISSUE_ID"
    echo "$APP_VERSION"
    echo "$PRODUCT_ID"
    echo "$COMMIT_ID"
    if [[ -f "$PROCESS_FILE" ]]
    then
       read -n 1 -p "there is already a automation process in progress. Do you want to continue or start over [y/n]" selection
       if [[ $selection == "y" ]]
       then
          resume_process "$@"
       else
         echo "deleting the exsiting process file"
         rm -rf "${PROCESS_DIR}"
       fi
    fi
    create_process_file
    checkout_branch
    cherry_pick_commit
    push_branch
    create_pr
}

resume_process() {
   echo 'Resuming existing process'
      
}

create_process_file() {
    PROCESS_FILE="${PROCESS_DIR}/${ISSUE_ID}_${APP_VERSION}_${PROCESS_DIR}_${COMMIT_ID}.txt"
    mkdir "$PROCESS_DIR"
    touch "$PROCESS_FILE"
}

# proc text:1 BRANCH_CHECKED_OUT IS-233 SUCCESS/FAILED
checkout_branch() {
    new_branch="issue/$ISSUE_ID"
    git checkout -b "$new_branch"
    git_branch=$(git symbolic-ref --short -q HEAD)
    if [[ $new_branch != "$git_branch" ]]
    then
       echo "branch checkout failed"
       echo "1 BRANCH_CHECKED_OUT issue/$ISSUE_ID FAILED" >> "$PROCESS_FILE"
       exit 1
    fi
    echo "1 BRANCH_CHECKED_OUT issue/$ISSUE_ID SUCCESS" >> "$PROCESS_FILE"
}

# proc text:2 COMMIT_CHERRY_PICKED commit_id SUCCESS/FAILED 
cherry_pick_commit() {
    git cherry-pick "$COMMIT_ID"
    checked_branch=$(git symbolic-ref --short -q HEAD)
    if [[ "$checked_branch" != "issue/$ISSUE_ID" ]]
    then
       echo "cherry-pick failed. Please fix and resume"
       echo "2 COMMIT_CHERRY_PICKED $COMMIT_ID FAILED" >> "$PROCESS_FILE"
    else
       echo "2 COMMIT_CHERRY_PICKED $COMMIT_ID SUCCESS" >> "$PROCESS_FILE"
    fi
}

# proc text:3 BRANCH_PUSHED IS-233 SUCCESS/FAILED
push_branch() {
    git push origin "issue/$ISSUE_ID"
    push_status=$(git diff "issue/$ISSUE_ID" "origin/issue/$ISSUE_ID")
    if [ -z "$push_status" ]
    then
       echo "3 BRANCH_PUSHED issue/$ISSUE_ID SUCCESS" >> "$PROCESS_FILE"
    else
       echo "3 BRANCH_PUSHED issue/$ISSUE_ID FAILED" >> "$PROCESS_FILE"
       exit 1
    fi      
}

# proc  text:4 PR_CREATED abc.com/pr/1 SUCCESS
create_pr() {
    pr_response=$(curl --location --request POST "$PROJECT_API_URL" \
    --header "Authorization: Basic $BIT_AUTH" \
    --header "Content-Type: application/json" \
    --data @<(cat <<EOF
{
    "title": "$ISSUE_ID PR",
    "source": {
        "branch": {
            "name": "issue/$ISSUE_ID"
        }
    },
    "destination": {
        "branch": {
            "name": "master"
        }
    }
}
EOF
)
)
    pr_link=$(echo "$pr_response" | jq -r .links.self.href)
    echo "$pr_link"
    if [ -z "$pr_link" ]
    then
       echo "4 PR_CREATED no_pr FAILED" >> "$PROCESS_FILE"
    else
       echo "4 PR_CREATED $pr_link SUCCESS" >> "$PROCESS_FILE"
       exit 1
    fi

}

if [[ $# -ne 4 ]]
then
    menu
else
    start "$@"
fi