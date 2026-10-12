BEGIN;
SELECT pg_advisory_xact_lock(726401991);

CREATE TEMP TABLE demo_movies ON COMMIT DROP AS
SELECT * FROM jsonb_to_recordset('__DEMO_CATALOG_JSON__'::jsonb) AS movie(
    "Slug" text, "Name" text, "OriginalName" text, "ReleaseDate" date,
    "Duration" integer, "AgeRating" integer, "Country" text,
    "Director" text, "Actor" text, "Genres" jsonb,
    "Description" text, "PosterPath" text
);

-- Существующие карточки, видимость и связи жанров не перезаписываются.
-- Служебный ключ сохраняет переименования и удаления администратора.
CREATE TEMP TABLE new_demo_movies ON COMMIT DROP AS
WITH inserted AS (
    INSERT INTO "Movies" (
        "Name", "OriginalName", "Duration", "AgeRating", "Description",
        "Director", "Actor", "Country", "PremiereDate", "WorldPremiere",
        "PosterPath", "Rating", "IsVisible", "CardImagePath"
    )
    SELECT "Name", "OriginalName", "Duration", "AgeRating", "Description",
        "Director", "Actor", "Country", "ReleaseDate", "ReleaseDate",
        "PosterPath", 0, true, "PosterPath"
    FROM demo_movies d
    WHERE NOT EXISTS (SELECT 1 FROM "DemoSeedRecords" marker WHERE marker."Key"='movie:'||d."Slug")
      AND NOT EXISTS (SELECT 1 FROM "Movies" m WHERE m."OriginalName"=d."OriginalName")
    RETURNING "Id", "OriginalName"
)
SELECT * FROM inserted;

INSERT INTO "Genres" ("Name")
SELECT DISTINCT names.name FROM demo_movies d
JOIN new_demo_movies m ON m."OriginalName"=d."OriginalName"
CROSS JOIN LATERAL jsonb_array_elements_text(d."Genres") names(name)
WHERE NOT EXISTS (SELECT 1 FROM "Genres" g WHERE g."NormalizedName"=lower(trim(names.name)))
AND NOT EXISTS (SELECT 1 FROM "DemoSeedRecords" marker WHERE marker."Key"='genre:'||lower(trim(names.name)))
ON CONFLICT DO NOTHING;

CREATE TEMP TABLE demo_genre_bindings ON COMMIT DROP AS
SELECT DISTINCT lower(trim(names.name)) AS canonical_name,g."Id" AS genre_id
FROM demo_movies d
CROSS JOIN LATERAL jsonb_array_elements_text(d."Genres") names(name)
LEFT JOIN "DemoSeedRecords" marker ON marker."Key"='genre:'||lower(trim(names.name))
JOIN "Genres" g ON (marker."Key" IS NOT NULL AND g."Id"=marker."EntityId")
    OR (marker."Key" IS NULL AND g."NormalizedName"=lower(trim(names.name)));

INSERT INTO "MovieGenres" ("MovieId", "GenreId")
SELECT m."Id", g.genre_id FROM demo_movies d
JOIN new_demo_movies m ON m."OriginalName"=d."OriginalName"
CROSS JOIN LATERAL jsonb_array_elements_text(d."Genres") names(name)
JOIN demo_genre_bindings g ON g.canonical_name=lower(trim(names.name))
ON CONFLICT DO NOTHING;

INSERT INTO "DemoSeedRecords" ("Key","EntityId")
SELECT 'movie:'||d."Slug", m."Id" FROM demo_movies d
JOIN "Movies" m ON m."OriginalName"=d."OriginalName"
ON CONFLICT DO NOTHING;

INSERT INTO "DemoSeedRecords" ("Key","EntityId")
SELECT 'genre:'||canonical_name,genre_id FROM demo_genre_bindings
ON CONFLICT DO NOTHING;
COMMIT;

SELECT "Name", extract(year FROM "WorldPremiere") AS "Год", "Country"
FROM "Movies" WHERE "IsVisible" ORDER BY "WorldPremiere", "Name";
