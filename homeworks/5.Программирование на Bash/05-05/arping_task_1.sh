#!/bin/bash
INTERFACE="$1"
PREFIX="${2:-NOT_SET}"
SUBNET="$3"
HOST="$4"

# Функция проверки Аргументов на их наличие и правильное написание
check_arg() {
        local arg="$1"
        if [[ -z "$arg" ]] || ( [[ "$arg" =~ ^[0-9]+$ ]] && [ "$arg" -ge "0" ] && [ "$arg" -le "255" ] ); then 
                return 0
        else
                echo "Error, ip must be 0 to 255"
                exit 6
        fi
}

# Функция запуска arping 
arping_run() {
        local prefix="$1"
        local subnet="$2"
        local host="$3"
        local arping_start='fullip="${prefix}.${subnet}.${host}"; echo "[*] IP : $fullip"; arping -c 3 -i "$INTERFACE" "$fullip" 2>/dev/null'

        if [[ -z "$subnet" ]]; then
                for subnet in {1..255}
                do
                        for host in {1..255}
                        do
                                eval "$arping_start"
                        done
                done
        elif [[ -z "$host" ]]; then
                for host in {1..255}
                do
                        eval "$arping_start"
                done
        else 
                eval "$arping_start"
        fi
}

trap 'echo "Arping exit (Ctrl-C)"; exit 1' 2

# Проверка выполнения кода под root
username=$(id -nu)
if [ "$username" != "root" ]; then
        echo "Please, use command: sudo bash `basename $0`."
        exit 1
fi

# Проверка задан ли префикс и интерфейс (не тронуто с задания)
if [[ -z "$INTERFACE" ]]; then
    echo "\$INTERFACE must be passed as first positional argument"
    exit 1
fi


# Проверка Префикса
IFS='.' read -ra prefixcut <<< "$PREFIX"
if [[ "$PREFIX" = "NOT_SET" ]] || [[ ! "${#prefixcut[@]}" -eq 2 ]]; then
        echo "\$PREFIX is incorrect or empty, please enter the text in the format xxx.xxx"
        exit 1
fi

# Запуск функций
for arg in "${prefixcut[0]}" "${prefixcut[1]}" "$SUBNET" "$HOST"
do
        check_arg "$arg"
done


arping_run "$PREFIX" "$SUBNET" "$HOST"
