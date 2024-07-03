#!/bin/bash

# Define the log file location for logging
LOG_FILE="/var/log/user_management.log"
# Define the location of the password file where the generated passwords for each user will be stored
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if the user file argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <user_file>"
    exit 1
fi

# Assign the first argument to USER_FILE
USER_FILE="$1"

# Ensure log file and password file exist and set proper permissions
touch "$LOG_FILE" "$PASSWORD_FILE"
chmod 600 "$LOG_FILE" "$PASSWORD_FILE"

# Create /var/secure directory if it doesn't exist
if [ ! -d "/var/secure" ]; then
    mkdir -p /var/secure
    chmod 700 /var/secure
    echo "$(date) - Created /var/secure directory." | tee -a "$LOG_FILE"
fi

# Function to log messages
log_message() {
    echo "$(date) - $1" | tee -a "$LOG_FILE"
}

# Function to generate a random 12 character alphanumeric password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Ensure the users.txt file exists
if [ ! -f "$USER_FILE" ]; then
    log_message "User file $USER_FILE does not exist. Exiting."
    exit 1
fi

# Function to create a user and set a password
create_user() {
    local username=$1

    if id "$username" &>/dev/null; then
        log_message "User $username already exists."
        return
    fi

    if groupadd "$username"; then
        if useradd -m -g "$username" "$username"; then
            log_message "User $username and group $username created."

            password=$(generate_password)
            if echo "$username:$password" | chpasswd; then
                log_message "Password set for user $username."
                echo "$username,$password" >> "$PASSWORD_FILE"
                log_message "Password for user $username saved to $PASSWORD_FILE."
            else
                log_message "Failed to set password for user $username."
            fi
        else
            log_message "Failed to create user $username."
        fi
    else
        log_message "Failed to create group $username."
    fi
}

# Function to add user to groups
assign_groups() {
    local username=$1
    local groups=$2

    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo "$group" | xargs)
        if [ -z "$group" ]; then
            log_message "Empty group name for user $username. Skipping."
            continue
        fi

        if ! getent group "$group" > /dev/null 2>&1; then
            if groupadd "$group"; then
                log_message "Group $group created."
            else
                log_message "Failed to create group $group."
                continue
            fi
        fi

        if usermod -aG "$group" "$username"; then
            log_message "User $username added to group $group."
        else
            log_message "Failed to add user $username to group $group."
        fi
    done
}

# Step 1: Create Users
log_message "Starting user creation process..."
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    if [ -z "$username" ]; then
        log_message "Empty username found. Skipping."
        continue
    fi

    create_user "$username"
done < "$USER_FILE"

# Step 2: Add Users to Groups
log_message "Starting group assignment process..."
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    if [ -z "$username" ]; then
        log_message "Empty username found. Skipping."
        continue
    fi

    if ! id "$username" &>/dev/null; then
        log_message "User $username does not exist. Skipping group assignment."
        continue
    fi

    assign_groups "$username" "$groups"
done < "$USER_FILE"

log_message "User and group creation process completed."

