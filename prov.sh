# source ./common.sh

# f=$(find "$TARGETS_DIR" -maxdepth 1 -type f -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)

# now=$(current_time_ms)
# mt=$(get_file_mtime "$f")

# echo "now=$now"
# echo "mtime=$mt"
# echo "diff_ms=$((now - mt))"




# cd /home/anton/voenka_kurs

# pkill -f '/home/anton/voenka_kurs/[k]p.sh'
# pkill -f '/home/anton/voenka_kurs/[r]ls.sh'
# pkill -f '/home/anton/voenka_kurs/[z]rdn.sh'
# pkill -f '/home/anton/voenka_kurs/[s]pro.sh'
# pkill -f '/home/anton/voenka_kurs/[G]enTargets.sh'

# rm -f pids/*.pid
# rm -rf pids/*.lock
# rm -f messages/to_kp/* messages/from_kp/* messages/heartbeat/* 2>/dev/null
# rm -rf temp/*
# rm -rf /tmp/GenTargets



#pgrep -af 'kp.sh|rls.sh|zrdn.sh|spro.sh|GenTargets.sh'





# rm -f pids/*.pid
# rm -rf pids/*.lock

# rm -f messages/to_kp/* 2>/dev/null
# rm -f messages/from_kp/* 2>/dev/null
# rm -f messages/heartbeat/* 2>/dev/null
# rm -rf messages/processing

# rm -f /logs/


# rm -rf temp/*
# rm -rf /tmp/GenTargets








cd /home/anton/voenka_kurs
source ./common.sh

echo "RLS1: X=$RLS1_X Y=$RLS1_Y RANGE=$RLS1_RANGE ANGLE=$RLS1_ANGLE SECTOR=$RLS1_SECTOR"
echo ""

total=$(scan_targets | wc -l)

visible=$(
scan_targets | while read -r id x y mt; do
    if is_in_sector "$RLS1_X" "$RLS1_Y" "$RLS1_RANGE" "$RLS1_ANGLE" "$RLS1_SECTOR" "$x" "$y"; then
        echo "$id"
    fi
done | wc -l
)

echo "Всего свежих целей:              $total"
echo "Геометрически видит РЛС1:        $visible"

if [[ "$total" -eq "$visible" ]]; then
    echo "OK: РЛС1 геометрически видит все свежие цели"
else
    echo "ПРОБЛЕМА: РЛС1 видит не все цели"
fi


cd /home/anton/voenka_kurs
source ./common.sh

echo "RLS2: X=$RLS2_X Y=$RLS2_Y RANGE=$RLS2_RANGE ANGLE=$RLS2_ANGLE SECTOR=$RLS2_SECTOR"
echo ""

total=$(scan_targets | wc -l)

visible=$(
scan_targets | while read -r id x y mt; do
    if is_in_sector "$RLS2_X" "$RLS2_Y" "$RLS2_RANGE" "$RLS2_ANGLE" "$RLS2_SECTOR" "$x" "$y"; then
        echo "$id"
    fi
done | wc -l
)

echo "Всего свежих целей:              $total"
echo "Геометрически видит РЛС2:        $visible"

if [[ "$total" -eq "$visible" ]]; then
    echo "OK: РЛС2 геометрически видит все свежие цели"
else
    echo "ПРОБЛЕМА: РЛС2 видит не все цели"
fi



cd /home/anton/voenka_kurs
source ./common.sh

echo "RLS3: X=$RLS3_X Y=$RLS3_Y RANGE=$RLS3_RANGE ANGLE=$RLS3_ANGLE SECTOR=$RLS3_SECTOR"
echo ""

total=$(scan_targets | wc -l)

visible=$(
scan_targets | while read -r id x y mt; do
    if is_in_sector "$RLS3_X" "$RLS3_Y" "$RLS3_RANGE" "$RLS3_ANGLE" "$RLS3_SECTOR" "$x" "$y"; then
        echo "$id"
    fi
done | wc -l
)

echo "Всего свежих целей:              $total"
echo "Геометрически видит РЛС3:        $visible"

if [[ "$total" -eq "$visible" ]]; then
    echo "OK: РЛС3 геометрически видит все свежие цели"
else
    echo "ПРОБЛЕМА: РЛС3 видит не все цели"
fi