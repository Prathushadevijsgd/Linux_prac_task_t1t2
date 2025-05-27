#!/bin/bash

# Load configuration
CONFIG_FILE="./backup.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found!" >&2
    exit 1
fi
source "$CONFIG_FILE"
LOCK_FILE="/tmp/backup.lock"

if [ -e "$LOCK_FILE" ]; then
    echo "Another instance of the script is running." >&2
    exit 1
else
    touch "$LOCK_FILE"
    # Ensure lock file is removed when script exits (even if it crashes)
    trap "rm -f $LOCK_FILE" EXIT
fi


# Create log file if it doesn't exist
touch "$LOG_FILE"
# Timestamp for backup filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE_NAME="backup_$TIMESTAMP.tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start backup
log "Starting backup of $SOURCE_DIR"
if [ ! -d "$SOURCE_DIR" ]; then
    log "Error: Source directory does not exist: $SOURCE_DIR"
    echo "Backup FAILED: Source directory not found." | mail -s "Backup Failed" "$EMAIL"
    exit 1
fi
tar -czf "$ARCHIVE_PATH" "$SOURCE_DIR" 2>>"$LOG_FILE"
if [ $? -ne 0 ]; then
    log "Backup FAILED!"
    echo "Backup FAILED. Check log: $LOG_FILE" | mail -s "Backup Failed" "$EMAIL"
    exit 1
else
    log "Backup completed: $ARCHIVE_PATH"
    echo "Backup SUCCESSFUL: $ARCHIVE_PATH" | mail -s "Backup Successful" "$EMAIL"
fi

# Delete backups older than retention period
log "Cleaning up backups older than $RETENTION_DAYS days"
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -exec rm {} \; -exec echo "Deleted: {}" >> "$LOG_FILE" \;

log "Backup script finished."

