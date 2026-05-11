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
echo "  Проверка DETECT за последние 10 минут"
echo "========================================="
echo ""

echo "--- 1. Все DETECT за последние 10 минут: РЛС, ЗРДН и СПРО ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
)
SELECT timestamp AS 'Время',
       CASE
           WHEN system_name LIKE 'RLS%' THEN 'РЛС'
           WHEN system_name LIKE 'ZRDN%' THEN 'ЗРДН'
           WHEN system_name LIKE 'SPRO%' THEN 'СПРО'
           ELSE 'Другая'
       END AS 'Класс',
       system_name AS 'Система',
       target_id AS 'ID_цели',
       target_type AS 'Тип',
       target_x AS 'X',
       target_y AS 'Y',
       message AS 'Сообщение'
FROM recent_detects
WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
  AND (
      system_name LIKE 'RLS%'
      OR system_name LIKE 'ZRDN%'
      OR system_name LIKE 'SPRO%'
  )
ORDER BY id DESC;
"
echo ""

echo "--- 2. Сводка DETECT за последние 10 минут по классам систем ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
),
classified AS (
    SELECT *,
           CASE
               WHEN system_name LIKE 'RLS%' THEN 'РЛС'
               WHEN system_name LIKE 'ZRDN%' THEN 'ЗРДН'
               WHEN system_name LIKE 'SPRO%' THEN 'СПРО'
               ELSE 'Другая'
           END AS system_class
    FROM recent_detects
    WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
      AND (
          system_name LIKE 'RLS%'
          OR system_name LIKE 'ZRDN%'
          OR system_name LIKE 'SPRO%'
      )
)
SELECT system_class AS 'Класс_системы',
       COUNT(*) AS 'Всего_DETECT',
       COUNT(DISTINCT target_id) AS 'Уникальных_целей',
       GROUP_CONCAT(DISTINCT target_type) AS 'Типы_целей'
FROM classified
GROUP BY system_class
ORDER BY COUNT(*) DESC;
"
echo ""

echo "--- 3. Сводка DETECT за последние 10 минут по каждой системе ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
)
SELECT system_name AS 'Система',
       COUNT(*) AS 'Всего_DETECT',
       COUNT(DISTINCT target_id) AS 'Уникальных_целей',
       GROUP_CONCAT(DISTINCT target_type) AS 'Типы_целей'
FROM recent_detects
WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
  AND (
      system_name LIKE 'RLS%'
      OR system_name LIKE 'ZRDN%'
      OR system_name LIKE 'SPRO%'
  )
GROUP BY system_name
ORDER BY COUNT(*) DESC;
"
echo ""

echo "--- 4. Сводка DETECT за последние 10 минут по системам и типам целей ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
)
SELECT system_name AS 'Система',
       target_type AS 'Тип_цели',
       COUNT(*) AS 'Всего_DETECT',
       COUNT(DISTINCT target_id) AS 'Уникальных_целей'
FROM recent_detects
WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
  AND (
      system_name LIKE 'RLS%'
      OR system_name LIKE 'ZRDN%'
      OR system_name LIKE 'SPRO%'
  )
GROUP BY system_name, target_type
ORDER BY system_name, COUNT(*) DESC;
"
echo ""

echo "--- 5. Цели и системы, которые их обнаружили за последние 10 минут ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
),
classified AS (
    SELECT id,
           timestamp,
           target_id,
           target_type,
           system_name,
           CASE
               WHEN system_name LIKE 'RLS%' THEN 'РЛС'
               WHEN system_name LIKE 'ZRDN%' THEN 'ЗРДН'
               WHEN system_name LIKE 'SPRO%' THEN 'СПРО'
               ELSE 'Другая'
           END AS system_class
    FROM recent_detects
    WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
      AND (
          system_name LIKE 'RLS%'
          OR system_name LIKE 'ZRDN%'
          OR system_name LIKE 'SPRO%'
      )
)
SELECT target_id AS 'ID_цели',
       target_type AS 'Тип',
       GROUP_CONCAT(DISTINCT system_class) AS 'Классы_систем',
       GROUP_CONCAT(DISTINCT system_name) AS 'Системы',
       COUNT(*) AS 'Всего_DETECT',
       MIN(timestamp) AS 'Первое_обнаружение',
       MAX(timestamp) AS 'Последнее_обнаружение'
FROM classified
GROUP BY target_id, target_type
ORDER BY MAX(id) DESC;
"
echo ""

echo "--- 6. Цели, которые за последние 10 минут обнаруживали несколько классов систем ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
),
classified AS (
    SELECT id,
           timestamp,
           target_id,
           target_type,
           system_name,
           CASE
               WHEN system_name LIKE 'RLS%' THEN 'РЛС'
               WHEN system_name LIKE 'ZRDN%' THEN 'ЗРДН'
               WHEN system_name LIKE 'SPRO%' THEN 'СПРО'
               ELSE 'Другая'
           END AS system_class
    FROM recent_detects
    WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
      AND (
          system_name LIKE 'RLS%'
          OR system_name LIKE 'ZRDN%'
          OR system_name LIKE 'SPRO%'
      )
)
SELECT target_id AS 'ID_цели',
       target_type AS 'Тип',
       GROUP_CONCAT(DISTINCT system_class) AS 'Классы_систем',
       GROUP_CONCAT(DISTINCT system_name) AS 'Системы',
       COUNT(DISTINCT system_class) AS 'Кол-во_классов',
       COUNT(*) AS 'Всего_DETECT',
       MIN(timestamp) AS 'Первое_обнаружение',
       MAX(timestamp) AS 'Последнее_обнаружение'
FROM classified
GROUP BY target_id, target_type
HAVING COUNT(DISTINCT system_class) > 1
ORDER BY COUNT(DISTINCT system_class) DESC, MAX(id) DESC;
"
echo ""

echo "--- 7. DETECT от РЛС за последние 10 минут ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name LIKE 'RLS%'
)
SELECT timestamp AS 'Время',
       system_name AS 'РЛС',
       target_id AS 'ID_цели',
       target_type AS 'Тип',
       target_x AS 'X',
       target_y AS 'Y',
       message AS 'Сообщение'
FROM recent_detects
WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
ORDER BY id DESC;
"
echo ""

echo "--- 8. DETECT от ЗРДН за последние 10 минут ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name LIKE 'ZRDN%'
)
SELECT timestamp AS 'Время',
       system_name AS 'ЗРДН',
       target_id AS 'ID_цели',
       target_type AS 'Тип',
       target_x AS 'X',
       target_y AS 'Y',
       message AS 'Сообщение'
FROM recent_detects
WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
ORDER BY id DESC;
"
echo ""

echo "--- 9. DETECT от СПРО за последние 10 минут ---"
sqlite3 -header -column "$DB_FILE" "
WITH recent_detects AS (
    SELECT *,
           datetime(
                strftime('%Y', 'now', 'localtime') || '-' ||
                substr(timestamp, 4, 2) || '-' ||
                substr(timestamp, 1, 2) || ' ' ||
                substr(timestamp, 7, 8)
           ) AS event_dt
    FROM journal
    WHERE event_type = 'DETECT'
      AND system_name LIKE 'SPRO%'
)
SELECT timestamp AS 'Время',
       system_name AS 'СПРО',
       target_id AS 'ID_цели',
       target_type AS 'Тип',
       target_x AS 'X',
       target_y AS 'Y',
       message AS 'Сообщение'
FROM recent_detects
WHERE event_dt >= datetime('now', 'localtime', '-10 minutes')
ORDER BY id DESC;
"
echo ""


echo "--- 10. Проверка связи: все объекты ONLINE и связь не потеряна ---"
sqlite3 -header -column "$DB_FILE" "
WITH expected_systems AS (
    SELECT '$RLS1_NAME' AS system_name, 'РЛС' AS system_class
    UNION ALL SELECT '$RLS2_NAME', 'РЛС'
    UNION ALL SELECT '$RLS3_NAME', 'РЛС'
    UNION ALL SELECT '$ZRDN1_NAME', 'ЗРДН'
    UNION ALL SELECT '$ZRDN2_NAME', 'ЗРДН'
    UNION ALL SELECT '$ZRDN3_NAME', 'ЗРДН'
    UNION ALL SELECT '$SPRO_NAME', 'СПРО'
),
latest_status_id AS (
    SELECT system_name,
           MAX(id) AS max_id
    FROM system_status
    GROUP BY system_name
),
latest_status AS (
    SELECT ss.system_name,
           ss.status,
           ss.ammo_left,
           ss.timestamp
    FROM system_status ss
    JOIN latest_status_id lsi
      ON ss.system_name = lsi.system_name
     AND ss.id = lsi.max_id
),
latest_heartbeat_loss AS (
    SELECT system_name,
           MAX(id) AS last_loss_id
    FROM journal
    WHERE event_type = 'HEARTBEAT'
      AND message LIKE '%НЕ ОТВЕЧАЕТ%'
    GROUP BY system_name
),
latest_heartbeat_restore AS (
    SELECT system_name,
           MAX(id) AS last_restore_id
    FROM journal
    WHERE event_type = 'HEARTBEAT'
      AND message LIKE '%восстановлена%'
    GROUP BY system_name
)
SELECT e.system_class AS 'Класс',
       e.system_name AS 'Система',
       COALESCE(ls.status, 'NO_DATA') AS 'Текущий_статус',
       COALESCE(CAST(ls.ammo_left AS TEXT), '-') AS 'Боекомплект',
       COALESCE(ls.timestamp, '-') AS 'Время_последнего_статуса',
       CASE
           WHEN ls.status = 'ONLINE'
            AND (
                loss.last_loss_id IS NULL
                OR COALESCE(rest.last_restore_id, 0) > loss.last_loss_id
            )
           THEN 'OK'
           WHEN ls.status IS NULL
           THEN 'НЕТ_ДАННЫХ'
           WHEN ls.status = 'OFFLINE'
           THEN 'СВЯЗЬ_ПОТЕРЯНА'
           WHEN loss.last_loss_id IS NOT NULL
            AND COALESCE(rest.last_restore_id, 0) < loss.last_loss_id
           THEN 'СВЯЗЬ_ПОТЕРЯНА'
           ELSE 'НЕ_ONLINE'
       END AS 'Итог'
FROM expected_systems e
LEFT JOIN latest_status ls
  ON e.system_name = ls.system_name
LEFT JOIN latest_heartbeat_loss loss
  ON e.system_name = loss.system_name
LEFT JOIN latest_heartbeat_restore rest
  ON e.system_name = rest.system_name
ORDER BY e.system_class, e.system_name;
"
echo ""


echo "--- 11. Общий итог по связи ---"
sqlite3 -header -column "$DB_FILE" "
WITH expected_systems AS (
    SELECT '$RLS1_NAME' AS system_name
    UNION ALL SELECT '$RLS2_NAME'
    UNION ALL SELECT '$RLS3_NAME'
    UNION ALL SELECT '$ZRDN1_NAME'
    UNION ALL SELECT '$ZRDN2_NAME'
    UNION ALL SELECT '$ZRDN3_NAME'
    UNION ALL SELECT '$SPRO_NAME'
),
latest_status_id AS (
    SELECT system_name,
           MAX(id) AS max_id
    FROM system_status
    GROUP BY system_name
),
latest_status AS (
    SELECT ss.system_name,
           ss.status
    FROM system_status ss
    JOIN latest_status_id lsi
      ON ss.system_name = lsi.system_name
     AND ss.id = lsi.max_id
),
latest_heartbeat_loss AS (
    SELECT system_name,
           MAX(id) AS last_loss_id
    FROM journal
    WHERE event_type = 'HEARTBEAT'
      AND message LIKE '%НЕ ОТВЕЧАЕТ%'
    GROUP BY system_name
),
latest_heartbeat_restore AS (
    SELECT system_name,
           MAX(id) AS last_restore_id
    FROM journal
    WHERE event_type = 'HEARTBEAT'
      AND message LIKE '%восстановлена%'
    GROUP BY system_name
),
check_result AS (
    SELECT e.system_name,
           CASE
               WHEN ls.status = 'ONLINE'
                AND (
                    loss.last_loss_id IS NULL
                    OR COALESCE(rest.last_restore_id, 0) > loss.last_loss_id
                )
               THEN 1
               ELSE 0
           END AS is_ok
    FROM expected_systems e
    LEFT JOIN latest_status ls
      ON e.system_name = ls.system_name
    LEFT JOIN latest_heartbeat_loss loss
      ON e.system_name = loss.system_name
    LEFT JOIN latest_heartbeat_restore rest
      ON e.system_name = rest.system_name
)
SELECT CASE
           WHEN MIN(is_ok) = 1 THEN 'OK: все объекты ONLINE, связь не потеряна'
           ELSE 'ПРОБЛЕМА: есть OFFLINE/NO_DATA/потеря связи'
       END AS 'Итог',
       SUM(is_ok) AS 'Исправных',
       COUNT(*) AS 'Всего_объектов'
FROM check_result;
"
echo ""

echo "========================================="
echo "  Конец проверки DETECT"
echo "========================================="




