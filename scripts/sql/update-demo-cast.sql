BEGIN;
SELECT pg_advisory_xact_lock(726401991);
CREATE TEMP TABLE demo_cast ON COMMIT DROP AS
SELECT * FROM jsonb_to_recordset('__CAST_JSON__'::jsonb)
AS cast_data("Slug" text,"OriginalName" text,"Actor" text,"LegacyActors" jsonb);

CREATE TEMP TABLE cast_bindings ON COMMIT DROP AS
SELECT d.*,m."Id" AS movie_id FROM demo_cast d
LEFT JOIN "DemoSeedRecords" marker ON marker."Key"='movie:'||d."Slug"
JOIN "Movies" m ON (marker."Key" IS NOT NULL AND m."Id"=marker."EntityId")
    OR (marker."Key" IS NULL AND m."OriginalName"=d."OriginalName");

UPDATE "Movies" m SET "Actor"=d."Actor" FROM cast_bindings d
WHERE m."Id"=d.movie_id AND d."LegacyActors" ? m."Actor"
AND NOT EXISTS(SELECT 1 FROM "DemoSeedRecords" marker WHERE marker."Key"='cast:v1:'||d."Slug");

INSERT INTO "DemoSeedRecords" ("Key","EntityId")
SELECT 'cast:v1:'||"Slug",movie_id FROM cast_bindings ON CONFLICT DO NOTHING;
COMMIT;
