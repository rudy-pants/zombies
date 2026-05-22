#!/bin/bash

# Define the Pi prompt
PI_PROMPT="Identify the most important issue in the issues section from the PLAN.md file. Once an issue is identified, address and resolve the issue, mark it as completed, and in a Discussion section underneath, create a summary for the issue you tackled. Then add and commit your changes. If you are not able to resolve the issue, or find yourself getting stuck, then abandon the progress, revert the changes, and write up a small summary of where you got stuck in the Discussion section."

# Function to count uncompleted issues
count_uncompleted() {
  grep -c '^- \[ \]' PLAN.md
}

# Function to count completed issues
count_completed() {
  grep -c '^- \[x\]' PLAN.md
}

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Main loop
issue_num=1
while true; do
  # Get current counts
  uncompleted_count=$(count_uncompleted)
  completed_count=$(count_completed)

  # If there are issues left, trigger Pi in a background tmux session
  if [ "$uncompleted_count" -gt 0 ]; then
    session_name="ralph-issue-${issue_num}"

    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Issue #${issue_num} of ${completed_count} already tackled${NC}"
    echo -e "${CYAN}  ${uncompleted_count} issue(s) remaining${NC}"
    echo -e "${CYAN}========================================${NC}"

    # Create a detached tmux session running the pi command
    tmux new-session -d -s "$session_name" "cd /home/rudy/code/zombies && pi -p \"$PI_PROMPT\""

    echo -e "${GREEN}[+] Detached tmux session: ${session_name}${NC}"
    echo -e "${YELLOW}[*] Pi is working on issue #${issue_num}...${NC}"

    # Wait for the tmux session to finish with periodic updates
    dots=""
    while tmux has-session -t "$session_name" 2>/dev/null; do
      dots=".${dots}"
      dots="${dots:0:4}"  # keep max 4 dots
      printf "\r${YELLOW}[*] Working${dots}   ${NC}"
      sleep 5
    done

    echo -e "\r${GREEN}[✓] Pi finished issue #${issue_num}${NC}"

    # --- 5 minute cooldown timer ---
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  Cooling down... (5 minutes)${NC}"
    echo -e "${YELLOW}  Press ENTER to skip the wait${NC}"
    echo -e "${YELLOW}========================================${NC}"

    cooldown_seconds=300
    skip=false

    # Use a loop with timeout-based read for the enter key check
    while [ "$cooldown_seconds" -gt 0 ]; do
      minutes=$((cooldown_seconds / 60))
      seconds=$((cooldown_seconds % 60))
      printf "\r${YELLOW}  ⏱  %02d:%02d remaining${NC}" "$minutes" "$seconds"

      # Check if user pressed Enter (non-blocking with 1 second timeout)
      if read -t 1 -r -N 1 keypress 2>/dev/null; then
        echo -e "\n${GREEN}  [!] Timer skipped by user${NC}"
        skip=true
        break
      fi

      cooldown_seconds=$((cooldown_seconds - 1))
    done

    if [ "$skip" = false ]; then
      echo -e "\n${GREEN}  [✓] Cool-down complete${NC}"
    fi
    echo ""

    issue_num=$((issue_num + 1))

  else
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  All issues completed! 🎉${NC}"
    echo -e "${GREEN}========================================${NC}"
    break
  fi
done

exit 0
