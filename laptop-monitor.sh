#!/bin/bash

# Ubuntu Laptop Health Monitor
# Sends metrics to n8n Cloud

WEBHOOK_URL="YOUR_N8N_PRODUCTION_WEBHOOK_URL"
WEBHOOK_TOKEN="YOUR_MONITORING_TOKEN"

HOSTNAME=$(hostname)
CPU_CORES=$(nproc)

# CPU usage using /proc/stat
read cpu user nice system idle iowait irq softirq steal rest < /proc/stat

TOTAL1=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE1=$((idle + iowait))

sleep 1

read cpu user nice system idle iowait irq softirq steal rest < /proc/stat

TOTAL2=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE2=$((idle + iowait))

TOTAL_DIFF=$((TOTAL2 - TOTAL1))
IDLE_DIFF=$((IDLE2 - IDLE1))

if [ "$TOTAL_DIFF" -gt 0 ]; then
    CPU_IDLE=$(awk "BEGIN {printf \"%.2f\", ($IDLE_DIFF/$TOTAL_DIFF)*100}")
else
    CPU_IDLE=100
fi

# Memory in GiB
MEM_TOTAL=$(awk '/MemTotal/ {printf "%.2f", $2/1048576}' /proc/meminfo)
MEM_AVAILABLE=$(awk '/MemAvailable/ {printf "%.2f", $2/1048576}' /proc/meminfo)

# Swap in GiB
SWAP_TOTAL=$(awk '/SwapTotal/ {printf "%.2f", $2/1048576}' /proc/meminfo)
SWAP_FREE=$(awk '/SwapFree/ {printf "%.2f", $2/1048576}' /proc/meminfo)

SWAP_USED=$(awk "BEGIN {printf \"%.2f\", $SWAP_TOTAL-$SWAP_FREE}")

# Root disk usage
DISK_USED=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

# Load averages
read LOAD1 LOAD5 LOAD15 REST < /proc/loadavg

# Timestamp
CHECKED_AT=$(date -Is)

# Create JSON and send to n8n
jq -n \
  --arg hostname "$HOSTNAME" \
  --argjson cpu_cores "$CPU_CORES" \
  --argjson cpu_idle_percent "$CPU_IDLE" \
  --argjson memory_total_gib "$MEM_TOTAL" \
  --argjson memory_available_gib "$MEM_AVAILABLE" \
  --argjson swap_total_gib "$SWAP_TOTAL" \
  --argjson swap_used_gib "$SWAP_USED" \
  --argjson disk_root_used_percent "$DISK_USED" \
  --argjson load_average_1m "$LOAD1" \
  --argjson load_average_5m "$LOAD5" \
  --argjson load_average_15m "$LOAD15" \
  --arg checked_at "$CHECKED_AT" \
  '{
    hostname: $hostname,
    cpu_cores: $cpu_cores,
    cpu_idle_percent: $cpu_idle_percent,
    memory_total_gib: $memory_total_gib,
    memory_available_gib: $memory_available_gib,
    swap_total_gib: $swap_total_gib,
    swap_used_gib: $swap_used_gib,
    disk_root_used_percent: $disk_root_used_percent,
    load_average_1m: $load_average_1m,
    load_average_5m: $load_average_5m,
    load_average_15m: $load_average_15m,
    checked_at: $checked_at
  }' | curl -sS -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "X-Monitor-Token: $WEBHOOK_TOKEN" \
    --data-binary @-

echo

