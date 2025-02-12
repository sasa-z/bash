#!/bin/bash

# Synopsis: This script performs a backup of a specified directory, manages backup rotation, and sends notifications upon completion or failure.

# Configuration
SOURCE_DIR="/path/to/source"               # Directory to be backed up
BACKUP_DIR="/path/to/backup"               # Where backups will be stored
MAX_BACKUPS=5                              # Number of backups to keep
LOG_FILE="/var/log/backup.log"             # Log file
EMAIL="your@email.com"                     # Email for notifications

# Function for logging messages
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> "$LOG_FILE"
    echo "$message"
}

# Function for sending email notifications
send_notification() {
    local subject="$1"
    local message="$2"
    echo "$message" | mail -s "$subject" "$EMAIL"
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR: Script must be run as root"
    exit 1
fi

# Check if the source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    log_message "ERROR: Source directory $SOURCE_DIR does not exist"
    send_notification "Backup Failed" "Source directory $SOURCE_DIR does not exist"
    exit 1
fi

# Create backup directory if it does not exist
mkdir -p "$BACKUP_DIR"

# Generate backup file name with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${TIMESTAMP}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

# Check available space
SOURCE_SIZE=$(du -sb "$SOURCE_DIR" | awk '{print $1}')
AVAILABLE_SPACE=$(df -B1 "$BACKUP_DIR" | awk 'NR==2 {print $4}')

if [[ $SOURCE_SIZE -gt $AVAILABLE_SPACE ]]; then
    log_message "ERROR: Not enough space for backup"
    send_notification "Backup Failed" "Not enough space for backup"
    exit 1
fi

# Perform the backup
log_message "Starting backup process..."

tar -czf "$BACKUP_PATH" "$SOURCE_DIR" 2>/tmp/backup_error

if [[ $? -ne 0 ]]; then
    ERROR_MSG=$(cat /tmp/backup_error)
    log_message "ERROR: Backup failed: $ERROR_MSG"
    send_notification "Backup Failed" "Backup failed: $ERROR_MSG"
    rm -f /tmp/backup_error
    exit 1
fi

rm -f /tmp/backup_error

# Verify the integrity of the backup file
if ! tar -tzf "$BACKUP_PATH" >/dev/null 2>&1; then
    log_message "ERROR: Backup file is corrupted"
    send_notification "Backup Failed" "Backup file is corrupted"
    rm -f "$BACKUP_PATH"
    exit 1
fi

# Delete old backups
cd "$BACKUP_DIR" || exit
BACKUP_COUNT=$(ls -1 backup_*.tar.gz 2>/dev/null | wc -l)

if [[ $BACKUP_COUNT -gt $MAX_BACKUPS ]]; then
    log_message "Deleting old backups..."
    ls -t backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
fi

# Calculate the size of the backup
BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)

# Successful completion
COMPLETION_MSG="Backup successfully completed\nFile: $BACKUP_FILE\nSize: $BACKUP_SIZE"
log_message "$COMPLETION_MSG"
send_notification "Backup Success" "$COMPLETION_MSG"

# Create MD5 checksum
md5sum "$BACKUP_PATH" > "${BACKUP_PATH}.md5"

# Set permissions
chmod 600 "$BACKUP_PATH"
chmod 600 "${BACKUP_PATH}.md5"
