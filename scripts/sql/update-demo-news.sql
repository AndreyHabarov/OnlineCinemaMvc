BEGIN;
SELECT pg_advisory_xact_lock(726401991);
CREATE TEMP TABLE demo_news ON COMMIT DROP AS
SELECT * FROM jsonb_to_recordset('__NEWS_JSON__'::jsonb)
AS d("Key" text,"Name" text,"Description" text,"ImagePath" text,"Date" timestamp,"Legacy" jsonb);
DO $$
DECLARE data_row record; news_row "News"%ROWTYPE; marker_id integer;
BEGIN
    FOR data_row IN SELECT * FROM demo_news LOOP
        SELECT "EntityId" INTO marker_id FROM "DemoSeedRecords" WHERE "Key"='news:'||data_row."Key";
        IF FOUND THEN
            SELECT * INTO news_row FROM "News" WHERE "Id"=marker_id;
            IF NOT FOUND THEN CONTINUE; END IF;
        ELSE
            SELECT * INTO news_row FROM "News"
            WHERE "Name"=data_row."Name" OR ("Name"=data_row."Legacy"->>'Name'
                AND "Description"=data_row."Legacy"->>'Description' AND "ImagePath"=data_row."Legacy"->>'ImagePath')
            ORDER BY "Id" LIMIT 1;
            IF NOT FOUND THEN
                INSERT INTO "News" ("Name","Description","ImagePath","Date")
                VALUES(data_row."Name",data_row."Description",data_row."ImagePath",data_row."Date")
                RETURNING * INTO news_row;
            END IF;
            INSERT INTO "DemoSeedRecords" ("Key","EntityId") VALUES('news:'||data_row."Key",news_row."Id");
        END IF;
        IF NOT EXISTS(SELECT 1 FROM "DemoSeedRecords" WHERE "Key"='news-presentation:v1:'||data_row."Key") THEN
            IF news_row."Name"=data_row."Legacy"->>'Name'
                AND news_row."Description"=data_row."Legacy"->>'Description'
                AND news_row."ImagePath"=data_row."Legacy"->>'ImagePath' THEN
                UPDATE "News" SET "Name"=data_row."Name","Description"=data_row."Description",
                    "ImagePath"=data_row."ImagePath" WHERE "Id"=news_row."Id";
            END IF;
            INSERT INTO "DemoSeedRecords" ("Key","EntityId") VALUES('news-presentation:v1:'||data_row."Key",news_row."Id");
        END IF;
    END LOOP;
END $$;
COMMIT;
