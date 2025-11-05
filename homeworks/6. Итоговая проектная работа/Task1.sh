#!/bin/bash

LOG_DIR="/var/log/proc_monitor"
LOG_FILE="$LOG_DIR/proc_monitor.log"
KNOWN_PIDS_FILE="$LOG_DIR/known_pids.list"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE" "$KNOWN_PIDS_FILE"

echo "Запуск скрипта $(date '+%Y.%m.%d %H:%M:%S')" >> "$LOG_FILE"

# Запуск с переданными заранее аргументами
if [[ $# -gt 0 ]]; then
	PARAMS=("$@")
else
	echo "Выберите параметры для отображения (введите номера через пробел):"
	echo "1) cmdline"
	echo "2) environ"
	echo "3) limits"
	echo "4) mounts"
	echo "5) status"
	echo "6) cwd"
	echo "7) fd"
	echo "8) fdinfo"
	echo "9) root"

	read -rp "Введите номера (например: 1 3 5 9): " CHOICES

	# Массив со всеми параметрами
	ALL_PARAMS=(cmdline environ limits mounts status cwd fd fdinfo root)

	# Формирование массива с выбранными параметрами
	PARAMS=()
	for n in $CHOICES; do
		idx=$((n - 1))
		if [[ $idx -ge 0 && $idx -lt ${#ALL_PARAMS[@]} ]]; then
			PARAMS+=("${ALL_PARAMS[$idx]}")
	  fi
	done

	# Проверка выбора не менее 4 параметров
	if [[ ${#PARAMS[@]} -lt 4 ]]; then
		echo "Вы не выбрали менее 4 параметров."
		exit 1
	fi
fi
# Ассоциативный массив для записи известныйх нам pid в отдельный файл для дальнейшей сверки
declare -A known_pids
while read -r pid; do
    [[ -n "$pid" ]] && known_pids["$pid"]=1
done < "$KNOWN_PIDS_FILE"

# Шапка таблицы
printf "%-8s %-25s" "PID" "Name"
for p in "${PARAMS[@]}"; do
#    printf " %-30s" "$p"
	case "$p" in
		"cmdline"|"environ"|"mounts")
			printf "%-30s" "$p"
			;;
		"limits")
			printf "%-10s" "$p"
			;;
		"status")
			printf "%-8s" "$p"
			;;
		"cwd"|"fd"|"fdinfo"|"root")
			printf "%-20s" "$p"
			;;
	esac
done
echo
printf "%0.s-" {1..140}; echo

# Прогон директории 
for pid_dir in /proc/[0-9]*; do
    pid=$(basename "$pid_dir")

	# Проверка директория ли нумерной "файл" и проверка доступности exe
	if [[ -d "$pid_dir" && -r "$pid_dir/exe" ]]; then
		exe_path=$(readlink -f "$pid_dir/exe" 2>/dev/null)
		proc_name=$(basename "$exe_path")
		
		# Ассоциативный массив с запитью результата в зависимости от параметра
		declare -A info
		for p in "${PARAMS[@]}"; do
			if [[ -r "$pid_dir/$p" ]]; then
				case "$p" in
					"cmdline"|"mounts"|"environ")
						info["$p"]=$(head -n 1 "$pid_dir/$p" 2>/dev/null | tr -d '\0' | cut -c1-28)
						;;
					"limits")
						info["$p"]=$(grep "Max cpu time" "$pid_dir/$p" 2>/dev/null | awk '{print $4}' | tr -d '\0' | cut -c1-9)
						;;
					"status")
						info["$p"]=$(grep "State" "$pid_dir/$p" | awk '{print $2}' | tr -d '\0' | cut -c1-8)
						;;
					"cwd")
						info["$p"]=$(basename $(readlink "$pid_dir/$p"))
						;;
					"fd")
						info["$p"]=$(ls -l /proc/2734/fd | grep -m 1 "socket:" | awk -F'-> ' '{print $2}')
						;;
					"fdinfo")
						fd=$(ls "$pid_dir/$p" | head -n 1)
						flag=$(grep "flags" "$pid_dir/$p/$fd" | awk '{print $2}')
						info["$p"]="$fd:$flag"
						;;
					"root")
						info["$p"]=$(readlink "$pid_dir/$p")
						;;
				esac
			else
				info["$p"]="N/A"
			fi
		done

		# Вывод таблицы
		printf "%-8s %-25s" "$pid" "$proc_name"
		for p in "${PARAMS[@]}"; do
			case "$p" in
				"cmdline"|"mounts"|"environ")
					printf "%-30s" "${info[$p]}"
					;;
				"limits")
					printf "%-10s" "${info[$p]}"
					;;
				"status")
					printf "%-8s" "${info[$p]}"
					;;
				"cwd"|"fd"|"fdinfo"|"root")
					printf "%-20s" "${info[$p]}"
					;;
			esac
		done
		echo

		# Проверка новых процессов
		if [[ -z "${known_pids[$pid]}" ]]; then
			echo "$(date '+%Y.%m.%d %H:%M:%S') Новый процесс: PID=$pid, Name=$proc_name" >> "$LOG_FILE"
			echo "$pid" >> "$KNOWN_PIDS_FILE"
		fi
	fi
done
