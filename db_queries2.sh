#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

DB_FILE="$DB_DIR/vko.db"

if [[ ! -f "$DB_FILE" ]]; then
    echo "ОШИБКА: База данных не найдена: $DB_FILE"
    echo "Запустите систему ВКО сначала (./start.sh)"
    exit 1
fi

echo "========================================="
echo "  Статистика работы системы ВКО"
echo "========================================="
echo ""



echo "--- 1. Активно выполняющиеся процессы системы ВКО (статус R) ---"

echo ""
echo "Основные процессы по PID-файлам со статусом R:"
printf "%-12s %-10s %-10s %-12s %s\n" "Компонент" "PID" "Статус" "Время" "Команда"
printf "%-12s %-10s %-10s %-12s %s\n" "---------" "---" "------" "-----" "-------"

for component in GenTargets KP RLS1 RLS2 RLS3 SPRO ZRDN1 ZRDN2 ZRDN3; do
    pidfile="$PID_DIR/${component}.pid"

    [[ -f "$pidfile" ]] || continue

    pid=$(cat "$pidfile" 2>/dev/null)
    [[ -n "$pid" ]] || continue

    if kill -0 "$pid" 2>/dev/null; then
        stat=$(ps -p "$pid" -o stat= 2>/dev/null | awk '{$1=$1; print}')

        if [[ "$stat" == R* ]]; then
            etime=$(ps -p "$pid" -o etime= 2>/dev/null | awk '{$1=$1; print}')
            cmd=$(ps -p "$pid" -o cmd= 2>/dev/null)
            printf "%-12s %-10s %-10s %-12s %s\n" "$component" "$pid" "$stat" "$etime" "$cmd"
        fi
    fi
done

echo ""
echo "Все найденные процессы проекта со статусом R:"
ps -eo pid,ppid,stat,etime,cmd | awk -v dir="$SCRIPT_DIR" '
NR == 1 {
    printf "%-10s %-10s %-8s %-12s %s\n", "PID", "PPID", "STAT", "TIME", "CMD"
    next
}

$3 ~ /^R/ && (index($0, dir "/GenTargets.sh") || index($0, dir "/kp.sh") || index($0, dir "/rls.sh") || index($0, dir "/spro.sh") || index($0, dir "/zrdn.sh")) {
    printf "%-10s %-10s %-8s %-12s ", $1, $2, $3, $4
    for (i = 5; i <= NF; i++) {
        printf "%s%s", $i, (i < NF ? " " : "")
    }
    printf "\n"
}
'

echo ""
echo "========================================="
echo "  Конец статистики"
echo "========================================="
