#!/bin/bash

# Check if the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if the input file is provided as an argument and direct on what to do if input file is not provided
if [ $# -ne 1 ]; then
  echo "Please run this instead: $0 <name-of-text-file>"
  exit 1
fi

INPUT_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure the log and password files exist and have the correct permissions
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
mkdir -p "$(dirname "$PASSWORD_FILE")"
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"
chown root:root "$PASSWORD_FILE"

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Read the input file and process each line
while IFS=";" read -r username groups; do
  # Trim any leading or trailing whitespace from username and groups
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  # Skip empty lines or lines with empty username
  if [ -z "$username" ]; then
    continue
  fi

  # Create the primary group with the same name as the username
  if ! getent group "$username" > /dev/null; then
    groupadd "$username"
    log_message "Group $username created."
  else
    log_message "Group $username already exists."
  fi

  # Create the user with the primary group
  if ! id "$username" > /dev/null 2>&1; then
    useradd -m -g "$username" "$username"
    log_message "User $username created with primary group $username."
  else
    log_message "User $username already exists."
  fi

  # Add user to additional groups
  if [ -n "$groups" ]; then
    usermod -aG "$(echo $groups | tr ',' ' ')" "$username"
    log_message "User $username added to groups: $groups."
  fi

  # Generate a random password for the user
  password=$(openssl rand -base64 12)
  echo "$username:$password" | chpasswd
  log_message "Password set for user $username."

  # Store the password securely
  echo "$username,$password" >> "$PASSWORD_FILE"

done < "$INPUT_FILE"

log_message "User creation script completed successfully."

exit 0
