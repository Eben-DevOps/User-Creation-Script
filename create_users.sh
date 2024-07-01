#!/bin/bash

# define the Log file location for logging
LOG_FILE="/var/log/user_management.log"

#define the location of the passwordfile where the generated password for each user will be stored
PASSWORD_FILE="/var/secure/user_passwords.txt"

#Define the location of the users files and groups for ceration of users nad groups
#You can Update this path if users.txt file is in a different directory
USER_FILE="users.txt" 

# Function to generate a random 12 character password for alphanumeric passwords
generate_password() {
    local PASSWORD_LENGTH=12
    echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c ${PASSWORD_LENGTH} ; echo '')"
}

# Ensure log file and password file exist by using the touch command to create them and if they exist, it does not overwrite
touch $LOG_FILE
touch $PASSWORD_FILE

# Read the file with user information and the groups to which they should belong to.
while IFS=';' read -r username groups; do
    # Remove leading/trailing whitespace
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Check if user already exists prior to creation
    if id "$username" &>/dev/null; then
        echo "$(date) - User $username already exists." | tee -a $LOG_FILE
        continue
    fi

    # Create user and personal group
    useradd -m -g $username $username
    echo "$(date) - User $username and group $username created." | tee -a $LOG_FILE

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

    # Generate and set password for each user that has been created
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$(date) - Password set for user $username." | tee -a $LOG_FILE

    # Save the password securely in the passwordfile
    echo "$username:$password" >> $PASSWORD_FILE
    echo "$(date) - Password for user $username saved to $PASSWORD_FILE." | tee -a $LOG_FILE
done < $USER_FILE
