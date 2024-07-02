#!/bin/bash

# Define the log file location for logging
LOG_FILE="/var/log/user_management.log"

# Define the location of the password file where the generated passwords for each user will be stored
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Define the location of the users file for creation of users and groups
USER_FILE="users.txt"

# Ensure log file and password file exist and set proper permissions
touch $LOG_FILE
chmod 600 $LOG_FILE
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Create /var/secure directory if it doesn't exist
if [ ! -d "/var/secure" ]; then
    mkdir -p /var/secure
    chmod 700 /var/secure
    echo "$(date) - Created /var/secure directory." | tee -a $LOG_FILE
fi

# Function to log messages
log_message() {
    echo "$(date) - $1" | tee -a $LOG_FILE
}

# Function to generate a random 12 character alphanumeric password
generate_password() {
    local PASSWORD_LENGTH=12
    echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c ${PASSWORD_LENGTH} ; echo '')"
}

# Ensure the users.txt file exists
if [ ! -f $USER_FILE ]; then
    log_message "User file $USER_FILE does not exist. Exiting."
    exit 1
fi

# Step 1: Create Users
log_message "Starting user creation process..."
while IFS=';' read -r username groups; do
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    if id "$username" &>/dev/null; then
        log_message "User $username already exists."
        continue
    fi

    groupadd $username
    if [ $? -ne 0 ]; then
        log_message "Failed to create group $username."
        continue
    fi

    useradd -m -g $username $username
    if [ $? -eq 0 ]; then
        log_message "User $username and group $username created."
    else
        log_message "Failed to create user $username."
        continue
    fi

    password=$(generate_password)
    echo "$username:$password" | chpasswd
    if [ $? -eq 0 ]; then
        log_message "Password set for user $username."
    else
        log_message "Failed to set password for user $username."
        continue
    fi

    echo "$username:$password" >> $PASSWORD_FILE
    log_message "Password for user $username saved to $PASSWORD_FILE."
done < $USER_FILE

# Step 2: Add Users to Groups
log_message "Starting group assignment process..."
while IFS=';' read -r username groups; do
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    if ! id "$username" &>/dev/null; then
        log_message "User $username does not exist. Skipping group assignment."
        continue
    fi

    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo $group | xargs)
        if ! getent group $group > /dev/null 2>&1; then
            groupadd $group
            log_message "Group $group created."
        fi
        usermod -aG $group $username
        log_message "User $username added to group $group."
    done
done < $USER_FILE

log_message "User and group creation process completed."
