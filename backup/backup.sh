#!/bin/bash

# Synopsis: This script performs a backup of a specified directory, manages backup rotation, and sends notifications upon completion or failure.

# Configuration
SOURCE_DIR="/home/sasa/training/docker"     # Directory to be backed up
BACKUP_DIR="/home/sasa/training/temp"       # Where backups will be stored
MAX_BACKUPS=5                              # Number of backups to keep
LOG_FILE="/home/sasa/training/temp/backup.log"             # Log file
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')         # Timestamp format for backup files


check_backup_dir() {
    local dir="$1"
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Backup directory does not exist. Creating: $dir"
        mkdir -p "$dir"
        
        # Check if creation was successful
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to create backup directory: $dir"
            return 1
        fi
    fi
    
    # Check write permissions
    if [ ! -w "$dir" ]; then
        echo "ERROR: No write permission in backup directory: $dir"
        return 1
    fi
    
    echo "Backup directory is ready: $dir"
    return 0
}

clean_up(){
    local location="$1"
    local files_to_delete=$(find "$location" -type f -name "*.tar.gz" -printf '%T@ %f\n' | \
                            sort -n | \
                            head -n +"$MAX_BACKUPS" | \
                            awk '{print $2}')
    
    echo "Cleaning up old backups: $files_to_delete"
    if [ -n "$files_to_delete" ]; then
        echo "Deleting old backups"
        while read -r file; do
            echo "Deleting: $file"
            rm "$location/$file"

            if [ $? -ne 0 ]; then
                echo "ERROR: Failed to delete old backup: $file"
                return 1
            fi
        done <<< "$files_to_delete"
        echo "Old backups cleaned up"
    else
        echo "No old backups to clean up"
    fi

    return 0
}

check_backup_dir "$BACKUP_DIR" || exit 1

BACKUP_NAME="backup_${TIMESTAMP}.tar.gz"

tar -czPf  "$BACKUP_DIR/$BACKUP_NAME" "$SOURCE_DIR"

if [ $? -ne 0 ]; then
    echo "ERROR: Backup failed!"
    exit 1
else
    echo "Backup successfully created: $BACKUP_NAME"
fi

clean_up "$BACKUP_DIR"