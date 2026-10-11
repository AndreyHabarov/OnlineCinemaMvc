BEGIN;

-- Повторные и параллельные загрузки одного каталога не создают дубликаты.
SELECT pg_advisory_xact_lock(hashtext('onlinecinema-demo-catalog-1990s'));

CREATE TEMP TABLE demo_movies ON COMMIT DROP AS
SELECT * FROM jsonb_to_recordset('__DEMO_CATALOG_JSON__'::jsonb) AS movie(
    "Name" text, "OriginalName" text, "ReleaseDate" date,
    "Duration" integer, "AgeRating" integer, "Country" text,
    "Director" text, "Actor" text, "Genres" jsonb,
    "Description" text, "PosterPath" text
);

INSERT INTO "Genres" ("Name")
SELECT DISTINCT genre.name
FROM demo_movies AS movie
CROSS JOIN LATERAL jsonb_array_elements_text(movie."Genres") AS genre(name)
WHERE NOT EXISTS (SELECT 1 FROM "Genres" AS existing WHERE existing."Name" = genre.name);

-- Старые фильмы сохраняются для связанных записей, но исчезают из афиши.
UPDATE "Movies" SET "IsVisible" = false
WHERE "OriginalName" NOT IN (SELECT "OriginalName" FROM demo_movies);

UPDATE "Movies" AS existing
SET "Name" = movie."Name", "Duration" = movie."Duration",
    "AgeRating" = movie."AgeRating", "Description" = movie."Description",
    "Director" = movie."Director", "Actor" = movie."Actor",
    "Country" = movie."Country", "PremiereDate" = movie."ReleaseDate",
    "WorldPremiere" = movie."ReleaseDate", "PosterPath" = movie."PosterPath",
    "CardImagePath" = movie."PosterPath", "IsVisible" = true
FROM demo_movies AS movie
WHERE existing."OriginalName" = movie."OriginalName";

INSERT INTO "Movies" (
    "Name", "OriginalName", "Duration", "AgeRating", "Description",
    "Director", "Actor", "Country", "PremiereDate", "WorldPremiere",
    "PosterPath", "Rating", "IsVisible", "CardImagePath"
)
SELECT "Name", "OriginalName", "Duration", "AgeRating", "Description",
    "Director", "Actor", "Country", "ReleaseDate", "ReleaseDate",
    "PosterPath", 0, true, "PosterPath"
FROM demo_movies AS movie
WHERE NOT EXISTS (
    SELECT 1 FROM "Movies" AS existing WHERE existing."OriginalName" = movie."OriginalName"
);

DELETE FROM "MovieGenres"
WHERE "MovieId" IN (
    SELECT existing."Id" FROM "Movies" AS existing
    INNER JOIN demo_movies AS movie ON movie."OriginalName" = existing."OriginalName"
);

INSERT INTO "MovieGenres" ("MovieId", "GenreId")
SELECT existing."Id", genre."Id"
FROM demo_movies AS movie
INNER JOIN "Movies" AS existing ON existing."OriginalName" = movie."OriginalName"
CROSS JOIN LATERAL jsonb_array_elements_text(movie."Genres") AS names(name)
INNER JOIN "Genres" AS genre ON genre."Name" = names.name;

COMMIT;

SELECT "Name", extract(year FROM "WorldPremiere") AS "Год", "Country"
FROM "Movies" WHERE "IsVisible" ORDER BY "WorldPremiere", "Name";
