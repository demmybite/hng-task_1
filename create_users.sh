#!/bin/bash

# Check if an input file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

# Function to generate a random password
generate_password() {
    tr -dc '[:alnum:]' < /dev/urandom | head -c 12
}

# Read input file and process each line
while IFS=';' read -r username groups; do

   username=$(echo "$username" | xargs)
   groups=$(echo "$groups" | xargs)

    # Check if user already exists, then create personal group then add user to personal group 
    if id "$username" &>/dev/null; then
        echo "User $username already exists."
        sudo groupadd "$username"
        sudo useradd -m -g "$username" "$username"

        for group in "${group_array[@]}"; do
            if ! getent group "$group" &>/dev/null; then
               sudo groupadd "$group"
            fi
            sudo usermod -aG "$group" "$username"
        done

    else
        # Create user
        sudo useradd "$username"
    fi

    # Create personal group (if not exists)
    if ! getent group "$username" &>/dev/null; then
        sudo groupadd "$username"
    fi

    # Add user to personal group
    sudo useradd -m -g "$username" "$username"

    # Create additional groups (if not exists)
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" &>/dev/null; then
            sudo groupadd "$group"
        fi
        sudo usermod -aG "$group" "$username"
    done

     # Generate random password
    password=$(generate_password)

    # Set password for user
    echo "$password" | sudo passwd --stdin "$username"

    # Log actions
    echo "User $username created with groups: $groups" >> "$log_file"

    # Store password securely
    echo "$username,$password" >> "$password_file"

    # Set permissions for home directory
    home_dir="/home/$username"
    sudo mkdir -p "$home_dir"
    sudo chown "$username:$username" "$home_dir"
    sudo chmod 700 "$home_dir"
done < "$input_file"

echo "User creation and setup completed successfully."
