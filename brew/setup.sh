#!/bin/bash

if test -f "$PWD/.lock"; then
  echo "Lock file present - Setup has already been ran"
  exit 0
fi

if ! command -v brew &> /dev/null
then
    # Install brew
    echo "Brew needs to be installed manually first"
    exit 1
fi

# Install from brew file
xargs brew install < "$PWD/brew-requirements.txt"

# Create lock
touch .lock
