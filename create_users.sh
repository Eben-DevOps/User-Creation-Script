#!/bin/bash

# Define the log file location for logging
LOG_FILE="/var/log/user_management.log"

# Define the location of the password file where the generated passwords for each user will be stored
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Define the location of the users file for creation of users and groups
# Update this path if users.txt file is in a different directory
USER_FILE="users.txt"

# Ensure log file and password file exist
touch $LOG_FILE
touch $PASSWORD_FILE

# Create /var/secure directory if it doesn't exist
if [ ! -d "/var/secure" ]; then
    mkdir -p /var/secure
    chmod 700 /var/secure
    echo "$(date) - Created /var/secure directory." | tee -a $LOG_FILE
fi

# Function to generate a random 12 character alphanumeric password
generate_password() {
    local PASSWORD_LENGTH=12
    echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c ${PASSWORD_LENGTH} ; echo '')"
}

# Step 1: Create Users
echo "Starting user creation process..." | tee -a $LOG_FILE
while IFS=';' read -r username groups; do
    # Remove leading/trailing whitespace
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "$(date) - User $username already exists." | tee -a $LOG_FILE
        continue
    fi

    # Create user and personal group
    groupadd $username
    if [ $? -ne 0 ]; then
        echo "$(date) - Failed to create group $username." | tee -a $LOG_FILE
        continue
    fi

    useradd -m -g $username $username
    if [ $? -eq 0 ]; then
        echo "$(date) - User $username and group $username created." | tee -a $LOG_FILE
    else
        echo "$(date) - Failed to create user $username." | tee -a $LOG_FILE
        continue
    fi

    # Generate and set password for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$(date) - Password set for user $username." | tee -a $LOG_FILE

    # Save the password securely
    echo "$username:$password" >> $PASSWORD_FILE
    echo "$(date) - Password for user $username saved to $PASSWORD_FILE." | tee -a $LOG_FILE
done < $USER_FILE

# Step 2: Add Users to Groups
echo "Starting group assignment process..." | tee -a $LOG_FILE
while IFS=';' read -r username groups; do
    # Remove leading/trailing whitespace
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Check if user exists before adding to groups
    if ! id "$username" &>/dev/null; then
        echo "$(date) - User $username does not exist. Skipping group assignment." | tee -a $LOG_FILE
        continue
    fi

    # Add user to additional groups specified in the users.txt file
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo $group | xargs)
        if ! getent group $group > /dev/null 2>&1; then
            groupadd $group
            echo "$(date) - Group $group created." | tee -a $LOG_FILE
        fi
        usermod -aG $group $username
        echo "$(date) - User $username added to group $group." | tee -a $LOG_FILE
    done
done < $USER_FILE

echo "User and group creation process completed." | tee -a $LOG_FILE
