ALTER TABLE marketing.content_items
    ADD COLUMN IF NOT EXISTS approved_at timestamptz,
    ADD COLUMN IF NOT EXISTS approved_by text,
    ADD COLUMN IF NOT EXISTS rendered_at timestamptz,
    ADD COLUMN IF NOT EXISTS rendered_assets jsonb;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'content_items_rendered_assets_object'
          AND conrelid = 'marketing.content_items'::regclass
    ) THEN
        ALTER TABLE marketing.content_items
            ADD CONSTRAINT content_items_rendered_assets_object
            CHECK (
                rendered_assets IS NULL
                OR jsonb_typeof(rendered_assets) = 'object'
            );
    END IF;
END
$$;
