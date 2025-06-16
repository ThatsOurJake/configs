#!/bin/sh
# gcd - Git checkout default

SANITISED_PWD=$(echo "$PWD" | sed 's/[^a-zA-Z0-9._-]/_/g')
DATA_FILE=$HOME/.gcd

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq must be installed."
    exit 1
fi

if [ ! -f $DATA_FILE ]; then
    echo "{}" > $DATA_FILE
fi

EXISTS=$(jq --arg SANITISED_PWD "$SANITISED_PWD" 'has($SANITISED_PWD)' $DATA_FILE)

if [ "$EXISTS" = "true" ]; then
    DEFAULT_BRANCH=$(jq --arg SANITISED_PWD "$SANITISED_PWD" '.[$SANITISED_PWD].default_branch' $DATA_FILE)
    DEFAULT_BRANCH=$(echo $DEFAULT_BRANCH | tr -d '"')
else
    DEFAULT_BRANCH=$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')
    jq --arg SANITISED_PWD "$SANITISED_PWD" --arg DEFAULT_BRANCH "$DEFAULT_BRANCH" \
    '.[$SANITISED_PWD] = { default_branch: $DEFAULT_BRANCH }' $DATA_FILE > tmp.$$.json && mv tmp.$$.json $DATA_FILE
fi

# Check if the current branch is the default branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
    echo "Already on the default branch: $CURRENT_BRANCH"
    exit 0
fi

if ! git diff-index --quiet HEAD --; then
    echo "You have uncommitted changes. Please commit or stash them before switching branches."
    exit 1
fi

git checkout $DEFAULT_BRANCH
