#!/bin/bash

# Define thresholds
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80
CLEANUP_INTERVAL=900  # 15 minuta u sekundima
last_cleanup=0

while true; do
    current_time=$(date +%s)
    
    # Get CPU usage
    cpu_usage=$(top -bn1 | awk '/%Cpu/ {print $2}')
    
    # Get free memory in GB
    free_memory=$(free -m | awk '/Mem:/ {print $4/1024}')
    
    # Check CPU
    if [ $(printf "%.0f" $cpu_usage) -gt 80 ]; then
        echo "$(date): CPU is overloaded: ${cpu_usage}%"
        ps aux | awk "\$3 > $CPU_THRESHOLD {print \$2}" | while read pid; do
            name=$(ps -p $pid -o comm=)
            echo "$(date): Killing process $name (PID: $pid)"
            kill -15 $pid
        done
    fi
    
    # Check memory
    if (( $(printf "%.0f" $free_memory) < 1 )); then
        echo "$(date): Low memory: ${free_memory}GB free"
        ps aux | awk "\$4 > $MEM_THRESHOLD {print \$2}" | while read pid; do
            name=$(ps -p $pid -o comm=)
            echo "$(date): Killing process $name (PID: $pid)"
            kill -15 $pid
        done
    fi
    
    # Clean /tmp directory every 15 minutes
    if (( current_time - last_cleanup >= CLEANUP_INTERVAL )); then
        echo "$(date): Cleaning /tmp directory..."
        find /tmp -type f -atime +7 -delete
        last_cleanup=$current_time
    fi

    # Check disk usage
    echo "$(date): Checking disk usage..."
    df -h | awk -v threshold=$DISK_THRESHOLD 'NR>1 && $5+0 > threshold {print $6": "$5" used"}' | while read line; do
        echo "$(date): WARNING - High disk usage detected: $line"
    done
    
    sleep 3
done