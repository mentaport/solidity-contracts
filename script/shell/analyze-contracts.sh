#!/bin/bash

# Define the path to the src and reports folders
src_folder="src"
report_path="$(pwd)/reports"

# Create reports folder if the folder does not exists
if [ ! -d "report_path" ]; then
    mkdir -p "$report_path"
fi


# Loop through all files in sub-folders of src
find "$src_folder" -type f -print0 | while IFS= read -r -d '' file; do
    echo "Processing file: $file"
    contract_name=$(basename "$file")
    slither $file &> "$report_path/${contract_name%.*}.txt"
done
