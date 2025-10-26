#!/bin/bash
INTERFACE="$1"
PREFIX="10.0"
SUBNET="2"
HOST=

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
        for host in {1..255}
        do
                eval "$arping_start"
        done
}

trap 'echo "Arping exit (Ctrl-C)"; exit 1' 2

# Проверка выполнения кода под root
username=$(id -nu)
if [ "$username" != "root" ]; then
        echo "Please, use command: sudo bash $(basename "$0")."
        exit 1
fi
# Проверка интерфейса на существование и на корректность
if [[ -z "$INTERFACE" ]]; then
    echo "\$INTERFACE must be passed as second positional argument"
    exit 1
fi
if ip link show dev "$INTERFACE" > /dev/null 2>&1; then
        return 0
else 
        echo "interface is not exist"
        exit 1
fi

# Деление префикса на составляющие
IFS='.' read -ra prefixcut <<< "$PREFIX"

# Запуск функций
for arg in "${prefixcut[0]}" "${prefixcut[1]}" "$SUBNET"
do
        check_arg "$arg"
done

arping_run "$PREFIX" "$SUBNET" "$HOST"
