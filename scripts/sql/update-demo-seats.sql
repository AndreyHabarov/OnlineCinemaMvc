BEGIN;
SELECT pg_advisory_xact_lock(726401991);
CREATE TEMP TABLE demo_hall_data ON COMMIT DROP AS
SELECT * FROM jsonb_to_recordset('__HALLS_JSON__'::jsonb)
AS h(slug text, name text, rows integer, "seatsPerRow" integer, "picturePath" text, description text, "legacyDescriptions" jsonb);

INSERT INTO "Halls" ("Name", "PicturePath", "Description")
SELECT name, "picturePath", description FROM demo_hall_data d
WHERE NOT EXISTS (SELECT 1 FROM "Halls" h WHERE h."Name"=d.name)
AND NOT EXISTS (SELECT 1 FROM "DemoSeedRecords" m WHERE m."Key"='hall:'||d.slug);

CREATE TEMP TABLE demo_hall_bindings ON COMMIT DROP AS
SELECT DISTINCT ON (d.slug) d.*, h."Id" AS hall_id
FROM demo_hall_data d LEFT JOIN "DemoSeedRecords" m ON m."Key"='hall:'||d.slug
JOIN "Halls" h ON (m."Key" IS NOT NULL AND h."Id"=m."EntityId") OR (m."Key" IS NULL AND h."Name"=d.name)
ORDER BY d.slug,h."Id";
INSERT INTO "DemoSeedRecords" ("Key","EntityId")
SELECT 'hall:'||slug,hall_id FROM demo_hall_bindings ON CONFLICT DO NOTHING;

UPDATE "Halls" h SET
"Description"=CASE WHEN d."legacyDescriptions" ? h."Description" THEN d.description ELSE h."Description" END,
"PicturePath"=CASE WHEN h."PicturePath"='/images/hall/'||d.slug||'.jpg' THEN d."picturePath" ELSE h."PicturePath" END
FROM demo_hall_bindings d WHERE h."Id"=d.hall_id
AND NOT EXISTS (SELECT 1 FROM "DemoSeedRecords" m WHERE m."Key"='hall-presentation:v2:'||d.slug);
INSERT INTO "DemoSeedRecords" ("Key","EntityId")
SELECT 'hall-presentation:v2:'||slug,hall_id FROM demo_hall_bindings ON CONFLICT DO NOTHING;

INSERT INTO "Seats" ("HallId","Row","Number","Price")
SELECT d.hall_id,r.number,s.number,0 FROM demo_hall_bindings d
CROSS JOIN LATERAL generate_series(1,d.rows) r(number)
CROSS JOIN LATERAL generate_series(1,d."seatsPerRow") s(number)
WHERE NOT EXISTS (SELECT 1 FROM "Seats" existing WHERE existing."HallId"=d.hall_id)
AND NOT EXISTS (SELECT 1 FROM "DemoSeedRecords" m WHERE m."Key"='layout:'||d.slug)
ON CONFLICT ("HallId","Row","Number") DO NOTHING;
INSERT INTO "DemoSeedRecords" ("Key","EntityId")
SELECT 'layout:'||slug,hall_id FROM demo_hall_bindings ON CONFLICT DO NOTHING;
COMMIT;
SELECT h."Name",count(s."Id") AS "Количество мест" FROM "Halls" h
LEFT JOIN "Seats" s ON s."HallId"=h."Id" GROUP BY h."Id" ORDER BY h."Id";
