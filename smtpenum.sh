#!/bin/bash
# Set IP and port
IP="10.10.10.10" #CHANGE THIS
PORT=25 #CHANGE THIS

# Set wordlist file path
WORDLIST="path/to/wordlist.txt" #CHANGE THIS

# Connect to telnet
exec 3<>/dev/tcp/$IP/$PORT
exec 9<$WORDLIST

count=0
last_line=""
while read -r line <&9; do
    if [[ "$line" == "$last_line" ]]; then
        echo "Skipping $line"
        continue
    fi

    echo "VRFY $line" >&3
    ((count++))

    if (( count % 20 == 0 )); then
        sleep 2s
    fi

    read -r response <&3
    echo "$response"

    # Check if connection was reset by peer
    if [[ "$response" == *"Connection reset by peer"* ]]; then
        echo "Connection was reset by peer. Reconnecting..."
        exec 3<>/dev/tcp/$IP/$PORT
        echo "VRFY $line" >&3
        sleep 2s
        read -r response <&3
        echo "$response"
    fi

    # Check if server response is "too many errors"
    if [[ "$response" == *"too many errors"* ]]; then
        echo "Connection interrupted, restablishing connection..."

        # Reconnect and pick up where it left off
        exec 3<>/dev/tcp/$IP/$PORT
        echo "VRFY $last_line" >&3
        sleep 2s
        read -r response <&3
        echo "$response"
    fi

    last_line="$line"
done

exec 3>&-
exec 9<&-
