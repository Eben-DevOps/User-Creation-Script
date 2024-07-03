# User and Group Management Script

## Overview
This script automates the creation of users and groups on a Linux system, sets passwords for users, and assigns users to specified groups. It logs all actions performed and ensures secure storage of generated passwords.

## Features
- **User Creation**: Creates users based on a provided user file.
- **Group Assignment**: Assigns users to specified groups.
- **Password Generation**: Generates a random 12-character alphanumeric password for each user.
- **Logging**: Logs all actions to `/var/log/user_management.log`.
- **Secure Password Storage**: Stores usernames and passwords in `/var/secure/user_passwords.txt` with secure permissions.

## Requirements
- The script must be run as root.
- The user file must be provided as a command-line argument.

## Usage
1. Ensure the script is executable:
    ```bash
    chmod +x user_management.sh
    ```

2. Run the script with the user file as an argument:
    ```bash
    sudo ./user_management.sh users.txt
    ```

## User File Format
The user file should contain lines in the following format:
- `username`: The username to be created.
- `group1,group2,group3`: Comma-separated list of groups to which the user will be assigned.

## Logging
All actions performed by the script are logged to `/var/log/user_management.log`.

## Secure Password Storage
Generated passwords are stored in `/var/secure/user_passwords.txt` in the format:
The file is created with secure permissions to ensure only the owner can read it.

## Example
Given a `users.txt` file with the following content:
Running the script will:
1. Create users `john` and `jane`.
2. Assign `john` to the `admin` and `developers` groups.
3. Assign `jane` to the `developers` and `designers` groups.
4. Generate passwords for `john` and `jane` and store them securely.
