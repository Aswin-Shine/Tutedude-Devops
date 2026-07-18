#!/bin/bash
read -p "Enter the student's score: " score

if [ "$score" -ge 90 ]; then
    echo "Grade: A"
elif [ "$score" -ge 80 ]; then
    echo "Grade: B"
elif [ "$score" -ge 70 ]; then
    echo "Grade: C"
elif [ "$score" -ge 60 ]; then
    echo "Grade: D"
else
    echo "Grade: F"
fi