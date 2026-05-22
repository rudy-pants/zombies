#!/bin/bash

# Define the Pi prompt
PI_PROMPT="Identify the most important issue in the issues section from the PLAN.md file, and try tackling it for the zombies_test4.html project. Once an issue is identified, address the issue, mark it as completed, and in a Discussion section underneath, create a summary for the issue you tackled. Then add and commit your changes."

# Function to count uncompleted issues
count_uncompleted() {
  grep -c '^- \[ \]' PLAN.md
}

# Main loop
do {
  # Get current count of uncompleted issues
  uncompleted_count=$(count_uncompleted)
  
  # If there are issues left, trigger Pi
  if [ $uncompleted_count -gt 0 ]; then
    echo "Triggering Pi for PLAN.md..."
    # Run your Pi agent command here (replace with actual command)
    # Example: pi_agent -p "$PI_PROMPT" PLAN.md
    
    # Wait 5 minutes for cooling
    echo "Waiting 5 minutes for cooling..."
    sleep 300
  else
    echo "All issues completed!"
    break
  fi
} while [ $uncompleted_count -gt 0 ]

exit 0