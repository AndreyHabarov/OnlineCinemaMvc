BEGIN;
SELECT pg_advisory_xact_lock(hashtext('onlinecinema-demo-seats'));

INSERT INTO "Halls" ("Name", "PicturePath", "Description")
SELECT name, picture, description FROM (VALUES
    ('IMAX Зал', '/images/hall/imax.jpg', 'Большой зал: 10 рядов по 25 мест.'),
    ('VIP Lounge', '/images/hall/vip.jpg', 'VIP-зал: 5 рядов по 8 мест.'),
    ('Классический Зал', '/images/hall/classic.jpg', 'Классический зал: 10 рядов по 12 мест.')
) AS hall(name, picture, description)
WHERE NOT EXISTS (SELECT 1 FROM "Halls" WHERE "Name" = hall.name);

WITH empty_halls AS (
    SELECT h."Id", h."Name" FROM "Halls" h
    WHERE h."Name" IN ('IMAX Зал','VIP Lounge','Классический Зал')
      AND NOT EXISTS (SELECT 1 FROM "Seats" s WHERE s."HallId"=h."Id")
)
INSERT INTO "Seats" ("HallId", "Row", "Number", "Price")
SELECT h."Id", r.number, s.number, 0
FROM empty_halls h
CROSS JOIN LATERAL generate_series(1, CASE WHEN h."Name"='VIP Lounge' THEN 5 ELSE 10 END) r(number)
CROSS JOIN LATERAL generate_series(1, CASE WHEN h."Name"='IMAX Зал' THEN 25 WHEN h."Name"='VIP Lounge' THEN 8 ELSE 12 END) s(number)
ON CONFLICT ("HallId","Row","Number") DO NOTHING;
COMMIT;

SELECT h."Name", count(s."Id") AS "Количество мест"
FROM "Halls" h LEFT JOIN "Seats" s ON s."HallId"=h."Id" GROUP BY h."Id" ORDER BY h."Id";
