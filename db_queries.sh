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

echo "--- 1. Остаток боеприпасов у ЗРДН и СПРО ---"
sqlite3 -header -column "$DB_FILE" "
WITH ammo_limits AS (
    SELECT '$SPRO_NAME' AS system_name, $SPRO_AMMO AS max_ammo
    UNION ALL SELECT '$ZRDN1_NAME', $ZRDN1_AMMO
    UNION ALL SELECT '$ZRDN2_NAME', $ZRDN2_AMMO
    UNION ALL SELECT '$ZRDN3_NAME', $ZRDN3_AMMO
),
shots_fired AS (
    SELECT system_name, COUNT(*) AS shots_count
    FROM journal
    WHERE event_type = 'SHOT'
    GROUP BY system_name
),
latest_status AS (
    SELECT s1.system_name, s1.ammo_left
    FROM system_status s1
    JOIN (
        SELECT system_name, MAX(id) AS max_id
        FROM system_status
        GROUP BY system_name
    ) s2
      ON s1.system_name = s2.system_name
     AND s1.id = s2.max_id
)
SELECT ammo_limits.system_name AS 'Система',
       ammo_limits.max_ammo AS 'Начальный_БК',
       COALESCE(shots_fired.shots_count, 0) AS 'Выстрелов',
       COALESCE(latest_status.ammo_left, ammo_limits.max_ammo) AS 'Осталось'
FROM ammo_limits
LEFT JOIN shots_fired ON shots_fired.system_name = ammo_limits.system_name
LEFT JOIN latest_status ON latest_status.system_name = ammo_limits.system_name
ORDER BY ammo_limits.system_name;
"
echo ""

echo "--- 2. Количество уничтоженных целей по системам ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Система',
       COUNT(*) AS 'Уничтожено'
FROM shots
WHERE result = 'DESTROYED'
GROUP BY system_name
ORDER BY COUNT(*) DESC;
"
echo ""

echo "--- 3. Самая результативная система ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Система',
       COUNT(*) AS 'Уничтожено'
FROM shots
WHERE result = 'DESTROYED'
GROUP BY system_name
ORDER BY COUNT(*) DESC
LIMIT 1;
"
echo ""

echo "--- 4. Самая меткая система (процент попаданий) ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Система',
       SUM(CASE WHEN result='DESTROYED' THEN 1 ELSE 0 END) AS 'Попадания',
       SUM(CASE WHEN result='MISS' THEN 1 ELSE 0 END) AS 'Промахи',
       COUNT(*) AS 'Всего_выстрелов',
       ROUND(100.0 * SUM(CASE WHEN result='DESTROYED' THEN 1 ELSE 0 END) / COUNT(*), 1) AS 'Точность_%'
FROM shots
GROUP BY system_name
ORDER BY ROUND(100.0 * SUM(CASE WHEN result='DESTROYED' THEN 1 ELSE 0 END) / COUNT(*), 1) DESC;
"
echo ""

echo "--- 5. Последние обнаруженные цели ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Система',
       target_id AS 'ID_цели',
       target_type AS 'Тип',
       target_x AS 'X',
       target_y AS 'Y',
       timestamp AS 'Время'
FROM journal
WHERE event_type = 'DETECT'
ORDER BY id DESC
LIMIT 20;
"
echo ""

echo "--- 6. Цели, двигавшиеся в направлении СПРО ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Обнаружено',
       target_id AS 'ID_цели',
       target_x AS 'X',
       target_y AS 'Y',
       timestamp AS 'Время'
FROM journal
WHERE event_type = 'SPRO_ALERT'
ORDER BY id DESC;
"
echo ""

echo "--- 7. Промахи ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Система',
       target_id AS 'ID_цели',
       target_type AS 'Тип',
       timestamp AS 'Время'
FROM shots
WHERE result = 'MISS'
ORDER BY id DESC
LIMIT 20;
"
echo ""

echo "--- 8. Попытки несанкционированного доступа ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Система',
       details AS 'Детали',
       timestamp AS 'Время'
FROM nsd_log
ORDER BY id DESC
LIMIT 10;
"
echo ""

echo "--- 9. Общая статистика ---"
echo -n "Всего событий в журнале: "
sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM journal;"
echo -n "Всего выстрелов: "
sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM journal WHERE event_type='SHOT';"
echo -n "Уничтожено целей: "
sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM shots WHERE result='DESTROYED';"
echo -n "Промахов: "
sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM shots WHERE result='MISS';"
echo -n "Попыток НСД: "
sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM nsd_log;"
echo ""

echo "--- 10. Уничтожено ЗРДН за последний час ---"
sqlite3 -header -column "$DB_FILE" "
SELECT system_name AS 'Система',
       COUNT(*) AS 'Уничтожено_за_час'
FROM shots
WHERE result = 'DESTROYED'
  AND system_name LIKE 'ZRDN%'
  AND datetime(
        strftime('%Y', 'now') || '-' ||
        substr(timestamp, 4, 2) || '-' ||
        substr(timestamp, 1, 2) || ' ' ||
        substr(timestamp, 7, 8)
      ) >= datetime('now', '-1 hour')
GROUP BY system_name;
"
echo ""



echo "--- 11. Цели обнаруженные и в РЛС и в СПРО ---"
sqlite3 -header -column "$DB_FILE" "
SELECT target_id AS 'ID_цели',
       target_type as 'Тип_цели',
       timestamp AS 'Время'
FROM journal
WHERE event_type = 'SPRO_ALERT'
  AND datetime(
        strftime('%Y', 'now') || '-' ||
        substr(timestamp, 4, 2) || '-' ||
        substr(timestamp, 1, 2) || ' ' ||
        substr(timestamp, 7, 8)
      ) >= datetime('now', '-1 hour')
    AND target_id IN (SELECT target_id FROM journal WHERE event_type = 'DETECT')
;
"
echo ""


echo "--- 12. Цели, обнаруженные РЛС и СПРО ---"
sqlite3 -header -column "$DB_FILE" "
WITH
first_rls_detect AS (
    SELECT target_id,
           MIN(id) AS rls_detect_id
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name LIKE 'RLS%'
      AND target_id IS NOT NULL
    GROUP BY target_id
),
rls_systems AS (
    SELECT target_id,
           GROUP_CONCAT(DISTINCT system_name) AS rls_list
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name LIKE 'RLS%'
      AND target_id IS NOT NULL
    GROUP BY target_id
),
first_spro_detect AS (
    SELECT target_id,
           MIN(id) AS spro_detect_id
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name = '$SPRO_NAME'
      AND target_id IS NOT NULL
    GROUP BY target_id
)
SELECT r.target_id AS 'ID_цели',
       COALESCE(jr.target_type, js.target_type) AS 'Тип_цели',
       rs.rls_list AS 'Обнаружена_РЛС',
       jr.timestamp AS 'Время_обнаружения_РЛС',
       js.timestamp AS 'Время_обнаружения_СПРО',
       '$SPRO_NAME' AS 'Обнаружена_СПРО'
FROM first_rls_detect r
JOIN first_spro_detect s
  ON r.target_id = s.target_id
JOIN rls_systems rs
  ON r.target_id = rs.target_id
JOIN journal jr
  ON jr.id = r.rls_detect_id
JOIN journal js
  ON js.id = s.spro_detect_id
ORDER BY js.id DESC;
"
echo ""



echo "--- 13. Цели, обнаруженные РЛС/СПРО, обстрелянные и уничтоженные СПРО ---"
sqlite3 -header -column "$DB_FILE" "
WITH
spro_destroyed AS (
    SELECT target_id,
           target_type,
           MIN(id) AS destroyed_shot_id,
           MIN(timestamp) AS destroyed_time
    FROM shots
    WHERE result = 'DESTROYED'
      AND system_name = '$SPRO_NAME'
      AND target_id IS NOT NULL
    GROUP BY target_id, target_type
),
rls_detects AS (
    SELECT target_id,
           MIN(id) AS first_rls_detect_id,
           GROUP_CONCAT(DISTINCT system_name) AS rls_list
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name LIKE 'RLS%'
      AND target_id IS NOT NULL
    GROUP BY target_id
),
rls_detect_details AS (
    SELECT j.target_id,
           j.timestamp AS first_rls_detect_time
    FROM journal j
    JOIN rls_detects r
      ON j.target_id = r.target_id
     AND j.id = r.first_rls_detect_id
),
spro_detects AS (
    SELECT target_id,
           MIN(id) AS first_spro_detect_id
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name = '$SPRO_NAME'
      AND target_id IS NOT NULL
    GROUP BY target_id
),
spro_detect_details AS (
    SELECT j.target_id,
           j.timestamp AS first_spro_detect_time
    FROM journal j
    JOIN spro_detects s
      ON j.target_id = s.target_id
     AND j.id = s.first_spro_detect_id
),
spro_shots AS (
    SELECT target_id,
           MIN(id) AS first_spro_shot_id
    FROM journal
    WHERE event_type = 'SHOT'
      AND system_name = '$SPRO_NAME'
      AND target_id IS NOT NULL
    GROUP BY target_id
),
spro_shot_details AS (
    SELECT j.target_id,
           j.timestamp AS first_spro_shot_time
    FROM journal j
    JOIN spro_shots sh
      ON j.target_id = sh.target_id
     AND j.id = sh.first_spro_shot_id
)
SELECT d.target_id AS 'ID_цели',
       d.target_type AS 'Тип',
       CASE
           WHEN r.target_id IS NOT NULL THEN 'ДА'
           ELSE 'НЕТ'
       END AS 'Обнаружена_РЛС',
       COALESCE(r.rls_list, '-') AS 'Какие_РЛС',
       COALESCE(rd.first_rls_detect_time, '-') AS 'Время_РЛС',
       CASE
           WHEN s.target_id IS NOT NULL THEN 'ДА'
           ELSE 'НЕТ'
       END AS 'Обнаружена_СПРО',
       COALESCE(sd.first_spro_detect_time, '-') AS 'Время_СПРО',
       CASE
           WHEN sh.target_id IS NOT NULL THEN 'ДА'
           ELSE 'НЕТ'
       END AS 'Был_выстрел_СПРО',
       COALESCE(shd.first_spro_shot_time, '-') AS 'Время_выстрела',
       d.destroyed_time AS 'Время_поражения',
       '$SPRO_NAME' AS 'Поражена_системой'
FROM spro_destroyed d
LEFT JOIN rls_detects r
  ON r.target_id = d.target_id
LEFT JOIN rls_detect_details rd
  ON rd.target_id = d.target_id
LEFT JOIN spro_detects s
  ON s.target_id = d.target_id
LEFT JOIN spro_detect_details sd
  ON sd.target_id = d.target_id
LEFT JOIN spro_shots sh
  ON sh.target_id = d.target_id
LEFT JOIN spro_shot_details shd
  ON shd.target_id = d.target_id
ORDER BY d.destroyed_shot_id DESC;
"
echo ""

echo "========================================="
echo "  Конец статистики"
echo "========================================="
