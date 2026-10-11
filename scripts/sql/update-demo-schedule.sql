BEGIN;
SELECT pg_advisory_xact_lock(hashtext('onlinecinema-demo-schedule'));

CREATE TEMP TABLE planned_sessions ON COMMIT DROP AS
WITH films AS (
    SELECT "Id", "Duration", row_number() OVER (ORDER BY "OriginalName") - 1 AS number
    FROM "Movies" WHERE "IsVisible"
        AND "OriginalName" IN (SELECT jsonb_array_elements_text('__MOVIE_NAMES__'::jsonb))
), halls AS (
    SELECT "Id", row_number() OVER (ORDER BY "Id") - 1 AS number
    FROM "Halls" ORDER BY "Id" LIMIT 3
), slots AS (
    SELECT * FROM jsonb_to_recordset('__SCHEDULE_JSON__'::jsonb)
        AS slot("DateStart" timestamp, "MovieNumber" integer, "HallNumber" integer, "Price" integer)
)
SELECT films."Id" AS "MovieId", halls."Id" AS "HallId", slots."DateStart", slots."Price", films."Duration"
FROM slots
JOIN films ON films.number = slots."MovieNumber"
JOIN halls ON halls.number = slots."HallNumber";

DO $$
BEGIN
    IF (SELECT count(*) FROM planned_sessions) <> __EXPECTED_COUNT__ THEN
        RAISE EXCEPTION 'Для расписания нужны все 12 фильмов каталога и минимум 3 зала';
    END IF;
    IF EXISTS (
        SELECT 1 FROM planned_sessions AS planned
        JOIN "Sessions" AS existing ON existing."HallId" = planned."HallId"
        JOIN "Movies" AS film ON film."Id" = existing."MovieId"
        WHERE planned."DateStart" < existing."DateStart" + make_interval(mins => film."Duration" + 20)
          AND planned."DateStart" + make_interval(mins => planned."Duration" + 20) > existing."DateStart"
          AND NOT (existing."MovieId" = planned."MovieId" AND existing."DateStart" = planned."DateStart")
    ) THEN
        RAISE EXCEPTION 'Расписание пересекается с существующими сеансами. Изменения отменены';
    END IF;
    IF EXISTS (SELECT 1 FROM planned_sessions WHERE "Duration" + 20 > 240) THEN
        RAISE EXCEPTION 'Фильм вместе с уборкой зала не помещается в четырёхчасовой слот';
    END IF;
END $$;

INSERT INTO "Sessions" ("MovieId", "HallId", "DateStart", "Price")
SELECT "MovieId", "HallId", "DateStart", "Price"
FROM planned_sessions AS planned
WHERE NOT EXISTS (
    SELECT 1 FROM "Sessions" AS existing
    WHERE existing."MovieId" = planned."MovieId" AND existing."HallId" = planned."HallId"
      AND existing."DateStart" = planned."DateStart"
);
COMMIT;
