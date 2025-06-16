#!/bin/sh
# Usage: gtidy

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null
then
    echo "whiptail could not be found. Please install it to use this script."
    echo "Helpful doc: https://command-not-found.com/whiptail"
    exit
fi

if [ ! -d ".git" ]; then
    echo "This script must be run in a git repository."
    exit 1
fi

ORIGINAL_TERM=$TERM
TERM="ansi"
LOCAL_BRANCHES=$(git branch | sed 's/^[* ] //')

# Check if .gcd file exists and if so read the default branch
if [ -f $HOME/.gcd ]; then
    SANITISED_PWD=$(echo "$PWD" | sed 's/[^a-zA-Z0-9._-]/_/g')
    DEFAULT_BRANCH=$(jq --arg SANITISED_PWD "$SANITISED_PWD" '.[$SANITISED_PWD].default_branch' $HOME/.gcd)
    DEFAULT_BRANCH=$(echo $DEFAULT_BRANCH | tr -d '"')
else
    DEFAULT_BRANCH=$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')
fi

if [ -n "$DEFAULT_BRANCH" ]; then
    LOCAL_BRANCHES=$(echo "$LOCAL_BRANCHES" | grep -v "$DEFAULT_BRANCH")
fi

RAW_ARR_BRANCHES=($LOCAL_BRANCHES)
ARR_BRANCHES=()
for i in "${!RAW_ARR_BRANCHES[@]}"; do
    CURRENT_ITEM=${RAW_ARR_BRANCHES[i]}
    ARR_BRANCHES+=($CURRENT_ITEM '' 'OFF')
done

eval CHOICES=($(whiptail --title "Git Tidy" --checklist  "Select the branches you want to delete:" 25 78 15 \
"${ARR_BRANCHES[@]}" 3>&1 1>&2 2>&3))

if [ $? -ne 0 ]; then
    exit 1
fi

if [ ${#CHOICES[@]} -eq 0 ]; then
    exit 1
fi

for choice in "${CHOICES[@]}"; do
    echo "Deleting branch: $choice"
    git branch -d $choice 2>/dev/null
done

echo "Branches deleted successfully."
