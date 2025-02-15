#!/bin/bash
# kill_ports.sh
# This script kills processes on UDP ports for each robot.
# It kills processes on ports starting at 19850 and 19950,
# incrementing by one for each robot.

# Set the number of robots from environment variable, defaulting to 1 if not set.
NUM_ROBOTS=${NUM_ROBOTS:-1}

echo "Killing processes on UDP ports for $NUM_ROBOTS robot(s)..."

for (( i=0; i<$NUM_ROBOTS; i++ )); do
    PORT1=$((19850 + i))
    PORT2=$((19950 + i))
    echo "Killing processes on UDP port $PORT1..."
    sudo fuser -k ${PORT1}/udp
    echo "Killing processes on UDP port $PORT2..."
    sudo fuser -k ${PORT2}/udp
done

echo "Done."
