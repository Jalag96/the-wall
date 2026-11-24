#!/bin/bash

URL="http://wall-web"
DURATION=60
TIMEOUT=5
CLIENTS=2

echo "Startar lasttest i $DURATION sekunder med $CLIENTS klienter"

end=$((SECONDS + DURATION))

for ((i=1; i<=CLIENTS; i++)); do
    (
        while (( SECONDS < end )); do
            curl -s -o /dev/null --max-time "$TIMEOUT" "$URL"
        done
    ) &
done

wait
echo "Lasttest klart"
