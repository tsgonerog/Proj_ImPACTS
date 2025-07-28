#!/bin/bash

# Delete only .out and .err files in the current directory (not recursive)
echo "Deleting the following .out and .err files from current directory:"
find . -maxdepth 1 -type f \( -name "*.out" -o -name "*.err" \) -print

# Ask for confirmation
read -p "Proceed with deletion? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    find . -maxdepth 1 -type f \( -name "*.out" -o -name "*.err" \) -delete
    echo "Deleted."
else
    echo "Aborted."
fi
