BEGIN;
SELECT pg_advisory_xact_lock(726401991);

CREATE TEMP TABLE planned_sessions ON COMMIT DROP AS
WITH films AS (
    SELECT m."Id",m."Duration",d.ordinality-1 AS number
    FROM jsonb_array_elements_text('__MOVIE_NAMES__'::jsonb) WITH ORDINALITY d(name,ordinality)
    JOIN "Movies" m ON m."OriginalName"=d.name AND m."IsVisible"
), halls AS (
    SELECT h."Id",d.ordinality-1 AS number
    FROM jsonb_array_elements_text('__HALL_SLUGS__'::jsonb) WITH ORDINALITY d(slug,ordinality)
    JOIN "DemoSeedRecords" marker ON marker."Key"='hall:'||d.slug
    JOIN "Halls" h ON h."Id"=marker."EntityId"
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
        RAISE EXCEPTION 'Для расписания нужны все 36 фильмов каталога и пять залов демокаталога';
    END IF;
    IF EXISTS (
        SELECT 1 FROM planned_sessions AS planned
        JOIN "Sessions" AS existing ON existing."HallId" = planned."HallId"
        JOIN "Movies" AS film ON film."Id" = existing."MovieId"
        WHERE planned."DateStart" < existing."DateStart" + make_interval(mins => film."Duration" + 30)
          AND planned."DateStart" + make_interval(mins => planned."Duration" + 30) > existing."DateStart"
          AND existing."DateStart" <> planned."DateStart"
    ) THEN
        RAISE EXCEPTION 'Расписание пересекается с существующими сеансами. Изменения отменены';
    END IF;
    IF EXISTS (SELECT 1 FROM planned_sessions WHERE "Duration" + 30 > 240) THEN
        RAISE EXCEPTION 'Фильм вместе с уборкой зала не помещается в четырёхчасовой слот';
    END IF;
END $$;

INSERT INTO "Sessions" ("MovieId", "HallId", "DateStart", "Price")
SELECT "MovieId", "HallId", "DateStart", "Price"
FROM planned_sessions AS planned
WHERE NOT EXISTS (
    SELECT 1 FROM "Sessions" AS existing
    WHERE existing."HallId" = planned."HallId"
      AND existing."DateStart" = planned."DateStart"
);
COMMIT;
