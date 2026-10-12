BEGIN;
SELECT pg_advisory_xact_lock(726401991);
CREATE TEMP TABLE demo_promotions ON COMMIT DROP AS
SELECT * FROM jsonb_to_recordset('__PROMOTIONS_JSON__'::jsonb)
AS d("Key" text,"Name" text,"DisplayName" text,"Description" text,"ImagePath" text,
    "ButtonText" text,"Link" text,"TargetGenreKey" text,"DateTime" timestamp,"LegacySnapshots" jsonb);

DO $$
DECLARE
    data_row record;
    promotion_row "Promotions"%ROWTYPE;
    marker_id integer;
    genre_id integer;
    resolved_link text;
BEGIN
    FOR data_row IN SELECT * FROM demo_promotions LOOP
        genre_id := NULL;
        SELECT g."Id" INTO genre_id FROM "DemoSeedRecords" marker
        JOIN "Genres" g ON g."Id"=marker."EntityId"
        WHERE marker."Key"='genre:'||data_row."TargetGenreKey";
        resolved_link := CASE WHEN genre_id IS NULL THEN data_row."Link"
            ELSE '/?genreId='||genre_id||'#movie-catalog' END;

        SELECT "EntityId" INTO marker_id FROM "DemoSeedRecords" WHERE "Key"='promotion:'||data_row."Key";
        IF FOUND THEN
            SELECT * INTO promotion_row FROM "Promotions" WHERE "Id"=marker_id;
            IF NOT FOUND THEN CONTINUE; END IF;
        ELSE
            SELECT p.* INTO promotion_row FROM "Promotions" p
            WHERE p."NormalizedName"=data_row."Name" OR EXISTS(
                SELECT 1 FROM jsonb_array_elements(data_row."LegacySnapshots") snapshot
                WHERE p."Name"=snapshot->>'Name' AND p."DisplayName"=snapshot->>'DisplayName'
                AND p."Description"=snapshot->>'Description' AND p."ImagePath"=snapshot->>'ImagePath'
                AND p."ButtonText"=snapshot->>'ButtonText' AND p."Link" IS NOT DISTINCT FROM snapshot->>'Link'
            )
            ORDER BY CASE WHEN p."NormalizedName"=data_row."Name" THEN 0 ELSE 1 END,p."Id" LIMIT 1;
            IF NOT FOUND THEN
                INSERT INTO "Promotions" ("Name","DisplayName","Description","ImagePath","ButtonText","Link","DateTime")
                VALUES(data_row."Name",data_row."DisplayName",data_row."Description",data_row."ImagePath",data_row."ButtonText",resolved_link,data_row."DateTime")
                RETURNING * INTO promotion_row;
            END IF;
            INSERT INTO "DemoSeedRecords" ("Key","EntityId") VALUES('promotion:'||data_row."Key",promotion_row."Id");
        END IF;

        IF NOT EXISTS(SELECT 1 FROM "DemoSeedRecords" WHERE "Key"='promotion-presentation:v2:'||data_row."Key") THEN
            IF EXISTS(SELECT 1 FROM jsonb_array_elements(data_row."LegacySnapshots") snapshot
                WHERE promotion_row."Name"=snapshot->>'Name' AND promotion_row."DisplayName"=snapshot->>'DisplayName'
                AND promotion_row."Description"=snapshot->>'Description' AND promotion_row."ImagePath"=snapshot->>'ImagePath'
                AND promotion_row."ButtonText"=snapshot->>'ButtonText' AND promotion_row."Link" IS NOT DISTINCT FROM snapshot->>'Link') THEN
                UPDATE "Promotions" SET "Name"=data_row."Name","DisplayName"=data_row."DisplayName",
                    "Description"=data_row."Description","ImagePath"=data_row."ImagePath",
                    "ButtonText"=data_row."ButtonText","Link"=resolved_link WHERE "Id"=promotion_row."Id";
            END IF;
            INSERT INTO "DemoSeedRecords" ("Key","EntityId") VALUES('promotion-presentation:v2:'||data_row."Key",promotion_row."Id");
        END IF;
    END LOOP;
END $$;
COMMIT;
