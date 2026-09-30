ALTER TYPE marketing.content_status ADD VALUE IF NOT EXISTS 'queued';
ALTER TYPE marketing.content_status ADD VALUE IF NOT EXISTS 'generating';
ALTER TYPE marketing.content_status ADD VALUE IF NOT EXISTS 'needs_revision';
ALTER TYPE marketing.content_status ADD VALUE IF NOT EXISTS 'ready_for_review';
ALTER TYPE marketing.content_status ADD VALUE IF NOT EXISTS 'failed';

ALTER TABLE marketing.content_items
    ADD COLUMN IF NOT EXISTS objective text,
    ADD COLUMN IF NOT EXISTS audience text,
    ADD COLUMN IF NOT EXISTS angle text,
    ADD COLUMN IF NOT EXISTS primary_format text,
    ADD COLUMN IF NOT EXISTS derived_formats jsonb NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS generation_attempts integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS generation_model text,
    ADD COLUMN IF NOT EXISTS last_error text,
    ADD COLUMN IF NOT EXISTS claimed_at timestamptz,
    ADD COLUMN IF NOT EXISTS generated_at timestamptz;

UPDATE marketing.content_items
SET objective = COALESCE(objective, 'awareness'),
    audience = COALESCE(audience, 'personas interesadas en práctica simbólica'),
    angle = COALESCE(angle, 'function'),
    primary_format = COALESCE(primary_format, 'carousel')
WHERE objective IS NULL
   OR audience IS NULL
   OR angle IS NULL
   OR primary_format IS NULL;

ALTER TABLE marketing.content_items
    ALTER COLUMN objective SET NOT NULL,
    ALTER COLUMN audience SET NOT NULL,
    ALTER COLUMN angle SET NOT NULL,
    ALTER COLUMN primary_format SET NOT NULL,
    ALTER COLUMN status SET DEFAULT 'queued';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'content_items_derived_formats_array'
          AND conrelid = 'marketing.content_items'::regclass
    ) THEN
        ALTER TABLE marketing.content_items
            ADD CONSTRAINT content_items_derived_formats_array
            CHECK (jsonb_typeof(derived_formats) = 'array');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'content_items_generation_attempts_nonnegative'
          AND conrelid = 'marketing.content_items'::regclass
    ) THEN
        ALTER TABLE marketing.content_items
            ADD CONSTRAINT content_items_generation_attempts_nonnegative
            CHECK (generation_attempts >= 0);
    END IF;
END
$$;
