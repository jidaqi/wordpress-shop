#!/bin/bash
while true; do
  echo "=== $(date) ==="
  free -m | awk 'NR==2{printf "Mem: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2}'
  awk '/oom_kill/ {print "OOM kills:", $NF}' /proc/vmstat
  sleep 30
done