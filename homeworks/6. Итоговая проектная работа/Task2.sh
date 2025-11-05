#!/bin/bash

LOG_DIR="/var/log/device_monitor"
LOG_FILE="$LOG_DIR/device_monitor.log"
KNOWN_DEVICE_FILE="$LOG_DIR/known_device.list"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE" "$KNOWN_DEVICE_FILE"

echo "Запуск скрипта $(date '+%Y.%m.%d %H:%M:%S')" >> "$LOG_FILE"

printf "%-8s %-8s %-8s %-35s %-25s %-25s" "Bus" "Vendor" "Version" "Name" "Phys" "Handlers"
echo
printf "%0.s-" {1..100}; echo

bus=""; vendor=""; version=""; name=""; phys=""; handlers=""

while IFS= read -r line || [[ -n "$line" ]]; do
    # Убираем пробелы в начале строки
    line=$(echo "$line" | sed 's/^[[:space:]]*//')

    if [[ $line == I:* ]]; then
        for field in $line; do
            case $field in
                Bus=*) bus=${field#Bus=} ;;
                Vendor=*) vendor=${field#Vendor=} ;;
                Version=*) version=${field#Version=} ;;
            esac
        done
    elif [[ $line == N:* ]]; then
        name=$(echo "$line" | sed -n 's/^N: Name="\([^"]*\)".*/\1/p')
    elif [[ $line == P:* ]]; then
        phys=$(echo "$line" | sed 's/^P: Phys=//')
		[[ -z "$phys" ]] && phys="[N/A]"
    elif [[ $line == H:* ]]; then
        handlers=$(echo "$line" | sed 's/^H: Handlers=//')
    elif [[ -z $line ]]; then
        if [[ -n $bus || -n $name || -n $handlers ]]; then
            printf "%-8s %-8s %-8s %-35s %-25s %-25s\n" "$bus" "$vendor" "$version" "$name" "$phys" "$handlers"
			device_id="$bus|$vendor|$version|$name|$phys|$handlers"
			if ! grep -Fxq "$device_id" "$KNOWN_DEVICE_FILE"; then
				echo "$device_id" >> "$KNOWN_DEVICE_FILE"
				echo "$(date '+%Y.%m.%d %H:%M:%S') Новый девайс: $device_id" >> "$LOG_FILE"
			fi
        fi
        bus=""; vendor=""; version=""; name=""; phys=""; handlers=""
    fi
done < /proc/bus/input/devices

# Вывод последнего устройства
if [[ -n $bus || -n $name || -n $handlers ]]; then
    printf "%-8s %-8s %-8s %-35s %-25s %-25s\n" "$bus" "$vendor" "$version" "$name" "$phys" "$handlers"
	device_id="$bus|$vendor|$version|$name|$phys|$handlers"
    if ! grep -Fxq "$device_id" "$KNOWN_DEVICE_FILE"; then
		echo "$device_id" >> "$KNOWN_DEVICE_FILE"
		echo "$(date '+%Y.%m.%d %H:%M:%S') Новый девайс: $device_id" >> "$LOG_FILE"
    fi
fi

