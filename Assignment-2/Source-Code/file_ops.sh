#!/bin/bash
file_name="assignment_output1.txt"

# Task 3: Write using redirection (>) and append (>>)
echo "Hello! This file was created using Bash." > "$file_name"
echo "DevOps automations rely heavily on shell scripts." >> "$file_name"
echo "Task 3 Complete: Written to $file_name"

# Task 4: Read using cat
echo -e "\nTask 4: Reading from $file_name:"
cat "$file_name"