#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [[ $EUID -eq 0 ]]; then
    echo "ОШИБКА: Запуск от имени root запрещен!" >&2
    exit 1
fi

if [[ -z "$BASH_VERSION" ]]; then
    echo "ОШИБКА: Требуется интерпретатор Bash!" >&2
    exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ОШИБКА: Скрипт остановки разрешен только в Linux. Текущая ОС: $(uname -s)" >&2
    exit 1
fi

# stop_component() {
#     local name="$1"
#     local pidfile="$PID_DIR/${name}.pid"

#     if [[ -f "$pidfile" ]]; then
#         local pid
#         pid=$(cat "$pidfile" 2>/dev/null)
#         if kill -0 "$pid" 2>/dev/null; then
#             kill "$pid" 2>/dev/null
#             sleep 0.5
#             if kill -0 "$pid" 2>/dev/null; then
#                 kill -9 "$pid" 2>/dev/null
#             fi
#             echo "[-] $name остановлен (PID: $pid)"
#         else
#             echo "[!] $name не работает (PID: $pid)"
#         fi
#         rm -f "$pidfile"
#     else
#         echo "[!] $name: PID-файл не найден"
#     fi
# }
stop_component() {
    local name="$1"
    local pidfile="$PID_DIR/${name}.pid"
    local lockdir="$PID_DIR/${name}.lock"

    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(cat "$pidfile" 2>/dev/null)

        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            sleep 0.5

            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null
            fi

            echo "[-] $name остановлен (PID: $pid)"
        else
            echo "[!] $name не работает (PID: ${pid:-unknown})"
        fi

        rm -f "$pidfile"
        rm -rf "$lockdir"
    else
        echo "[!] $name: PID-файл не найден"
        rm -rf "$lockdir"
    fi
}

# stop_by_name() {
#     local component="$1"
#     case "$component" in
#         gen|generator)
#             stop_component "GenTargets"
#             pkill -f "GenTargets.sh" 2>/dev/null
#             echo "[-] Генератор целей остановлен"
#             ;;
#         kp)
#             stop_component "KP_VKO"
#             ;;
#         kp) stop_component "KP" ;;
#         rls1) stop_component "RLS1" ;;
#         rls2) stop_component "RLS2" ;;
#         rls3) stop_component "RLS3" ;;
#         zrdn1) stop_component "ZRDN1" ;;
#         zrdn2) stop_component "ZRDN2" ;;
#         zrdn3) stop_component "ZRDN3" ;;
#         spro) stop_component "SPRO" ;;
#         *)
#             echo "Неизвестный компонент: $component"
#             echo "Доступные: gen, kp, rls1, rls2, rls3, zrdn1, zrdn2, zrdn3, spro"
#             return 1
#             ;;
#     esac
# }
stop_by_name() {
    local component="$1"
    case "$component" in
        gen|generator)
            stop_component "GenTargets"
            pkill -f "$SCRIPT_DIR/[G]enTargets.sh" 2>/dev/null
            echo "[-] Генератор целей остановлен"
            ;;
        kp)
            stop_component "KP"
            ;;
        rls1) stop_component "RLS1" ;;
        rls2) stop_component "RLS2" ;;
        rls3) stop_component "RLS3" ;;
        zrdn1) stop_component "ZRDN1" ;;
        zrdn2) stop_component "ZRDN2" ;;
        zrdn3) stop_component "ZRDN3" ;;
        spro) stop_component "SPRO" ;;
        *)
            echo "Неизвестный компонент: $component"
            echo "Доступные: gen, kp, rls1, rls2, rls3, zrdn1, zrdn2, zrdn3, spro"
            return 1
            ;;
    esac
}

if [[ -n "$1" ]]; then
    stop_by_name "$1"
else
    echo "========================================="
    echo "  Остановка системы ВКО"
    echo "========================================="
    echo ""

    stop_component "ZRDN3"
    stop_component "ZRDN2"
    stop_component "ZRDN1"
    stop_component "SPRO"
    stop_component "RLS3"
    stop_component "RLS2"
    stop_component "RLS1"
    stop_component "KP"

    stop_component "GenTargets"
    pkill -f '/home/anton/voenka_kurs/[k]p.sh' 2>/dev/null
    pkill -f '/home/anton/voenka_kurs/[r]ls.sh' 2>/dev/null
    pkill -f '/home/anton/voenka_kurs/[z]rdn.sh' 2>/dev/null
    pkill -f '/home/anton/voenka_kurs/[s]pro.sh' 2>/dev/null
    pkill -f '/home/anton/voenka_kurs/[G]enTargets.sh' 2>/dev/null

    rm -f "$PID_DIR/"*.pid 2>/dev/null
    rm -rf "$PID_DIR/"*.lock 2>/dev/null

    echo ""
    echo "========================================="
    echo "  Все системы ВКО остановлены"
    echo "========================================="
fi
