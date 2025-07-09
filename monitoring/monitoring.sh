#!/bin/bash

# Define thresholds and paths
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80
CLEANUP_INTERVAL=900
LOG_FILE="/var/log/system_monitor.log"
last_cleanup=0

# Function for logging
log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

while true; do
    current_time=$(date +%s)
    
    # Get CPU usage
    cpu_usage=$(top -bn1 | awk '/%Cpu/ {print $2}')
    
    # Get free memory in GB
    free_memory=$(free -m | awk '/Mem:/ {print $4/1024}')
    
    # Check CPU
    if [ $(printf "%.0f" $cpu_usage) -gt 80 ]; then
        log_message "CPU is overloaded: ${cpu_usage}%"
        ps aux | awk "\$3 > $CPU_THRESHOLD {print \$2}" | while read pid; do
            name=$(ps -p $pid -o comm=)
            log_message "Killing process $name (PID: $pid)"
            kill -15 $pid
        done
    fi
    
    # Check memory
    if (( $(printf "%.0f" $free_memory) < 1 )); then
        log_message "Low memory: ${free_memory}GB free"
        ps aux | awk "\$4 > $MEM_THRESHOLD {print \$2}" | while read pid; do
            name=$(ps -p $pid -o comm=)
            log_message "Killing process $name (PID: $pid)"
            kill -15 $pid
        done
    fi
    
    # Clean /tmp directory every 15 minutes
    if (( current_time - last_cleanup >= CLEANUP_INTERVAL )); then
        log_message "Cleaning /tmp directory..."
        deleted_files=$(find /tmp -type f -atime +7 -delete -print | wc -l)
        log_message "Deleted $deleted_files files from /tmp"
        last_cleanup=$current_time
    fi

    # Check disk usage
    df -h | awk -v threshold=$DISK_THRESHOLD 'NR>1 && $5+0 > threshold {print $6": "$5" used"}' | while read line; do
        log_message "WARNING - High disk usage detected: $line"
    done

    # Create daily summary report at midnight
    if [ "$(date +%H:%M)" == "00:00" ]; then
        log_message "=== Daily Summary Report ==="
        log_message "Top CPU-consuming processes:"
        ps aux | sort -nr -k 3 | head -5 >> "$LOG_FILE"
        log_message "Top memory-consuming processes:"
        ps aux | sort -nr -k 4 | head -5 >> "$LOG_FILE"
        log_message "Disk usage summary:"
        df -h >> "$LOG_FILE"
        log_message "=== End of Daily Report ==="
    fi
    
    sleep 3
done