CREATE SCHEMA IF NOT EXISTS marketing;

CREATE TYPE marketing.content_status AS ENUM (
    'idea',
    'fact_checked',
    'generated',
    'review',
    'queued',
    'generating',
    'needs_revision',
    'ready_for_review',
    'approved',
    'rendered',
    'scheduled',
    'published',
    'measured',
    'rejected',
    'failed'
);

CREATE TABLE marketing.content_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    external_key text NOT NULL UNIQUE,
    pillar text NOT NULL,
    objective text NOT NULL,
    audience text NOT NULL,
    angle text NOT NULL,
    primary_format text NOT NULL,
    derived_formats jsonb NOT NULL DEFAULT '[]'::jsonb,
    premise text NOT NULL,
    facts jsonb NOT NULL DEFAULT '[]'::jsonb,
    sources jsonb NOT NULL DEFAULT '[]'::jsonb,
    asset jsonb,
    warnings jsonb NOT NULL DEFAULT '[]'::jsonb,
    generated_content jsonb,
    status marketing.content_status NOT NULL DEFAULT 'queued',
    content_hash text UNIQUE,
    generation_attempts integer NOT NULL DEFAULT 0,
    generation_model text,
    last_error text,
    claimed_at timestamptz,
    generated_at timestamptz,
    scheduled_at timestamptz,
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT content_items_derived_formats_array
        CHECK (jsonb_typeof(derived_formats) = 'array'),
    CONSTRAINT content_items_generation_attempts_nonnegative
        CHECK (generation_attempts >= 0)
);

CREATE TABLE marketing.publications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    content_item_id uuid NOT NULL REFERENCES marketing.content_items(id) ON DELETE CASCADE,
    channel text NOT NULL,
    remote_id text,
    remote_url text,
    state text NOT NULL DEFAULT 'pending',
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (content_item_id, channel)
);

CREATE TABLE marketing.metric_snapshots (
    id bigserial PRIMARY KEY,
    publication_id uuid NOT NULL REFERENCES marketing.publications(id) ON DELETE CASCADE,
    captured_at timestamptz NOT NULL DEFAULT now(),
    metrics jsonb NOT NULL
);

CREATE INDEX content_items_status_scheduled_idx
    ON marketing.content_items (status, scheduled_at);

CREATE INDEX metric_snapshots_publication_captured_idx
    ON marketing.metric_snapshots (publication_id, captured_at DESC);
