#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script needs root priviledge"
   exit 1
fi

# Log file and password file
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create the secure directory if it doesn't exist
mkdir -p /var/secure
chmod 700 /var/secure

# Check if the input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <user-file>"
    exit 1
fi

# Ensure log and password files exist
touch $LOG_FILE
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Function to generate a random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo ''
}

# Process the input file
while IFS=';' read -r username groups; do
    username=$(echo $username | xargs) # Trim whitespace
    groups=$(echo $groups | xargs) # Trim whitespace

    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists, skipping." | tee -a $LOG_FILE
        continue
    fi

    # Create the user with their personal group
    useradd -m -s /bin/bash "$username" -g "$username"
    if [ $? -ne 0 ]; then
        echo "Failed to create user $username" | tee -a $LOG_FILE
        continue
    fi
    echo "Created user $username with personal group $username" | tee -a $LOG_FILE

    # Add user to additional groups
    IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
        group=$(echo $group | xargs) # Trim whitespace
        if [ -n "$group" ]; then
            # Create group if it doesn't exist
            if ! getent group "$group" > /dev/null; then
                groupadd "$group"
                if [ $? -ne 0 ]; then
                    echo "Failed to create group $group" | tee -a $LOG_FILE
                    continue
                fi
                echo "Created group $group" | tee -a $LOG_FILE
            fi
            usermod -aG "$group" "$username"
            if [ $? -ne 0 ]; then
                echo "Failed to add user $username to group $group" | tee -a $LOG_FILE
            else
                echo "Added user $username to group $group" | tee -a $LOG_FILE
            fi
        fi
    done

    # Generate and set a random password for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    if [ $? -ne 0 ]; then
        echo "Failed to set password for $username" | tee -a $LOG_FILE
    else
        echo "Set password for $username" | tee -a $LOG_FILE
        echo "$username,$password" >> $PASSWORD_FILE
    fi
done < "$1"

echo "User creation process completed." | tee -a $LOG_FILE
