-- Kampive schema: apply manually to the existing kampive database as its administrator.
-- Requires the empty kampive schema created during provisioning.
-- Not a migration and never executed automatically by Docker or Spring.
-- Deliberately fails on existing tables; the transaction prevents partial application.
BEGIN;

DO $$ BEGIN
    IF current_database() <> 'kampive' THEN
        RAISE EXCEPTION 'Connect to the kampive database before applying this script';
    END IF;
END $$;

SET LOCAL search_path TO kampive, public;

CREATE TABLE continent (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_continent UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE country (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_country UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_continent UUID NOT NULL REFERENCES continent (uuid_continent),
    name VARCHAR(120) NOT NULL UNIQUE,
    iso_code CHAR(2) NOT NULL UNIQUE,
    image_url TEXT,
    CHECK (iso_code ~ '^[A-Z]{2}$')
);

CREATE TABLE administrative_division (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_administrative_division UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_country UUID NOT NULL REFERENCES country (uuid_country),
    name VARCHAR(120) NOT NULL,
    code VARCHAR(20) NOT NULL,
    UNIQUE (uuid_country, code)
);

CREATE TABLE city (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_city UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_administrative_division UUID NOT NULL REFERENCES administrative_division (uuid_administrative_division),
    name VARCHAR(150) NOT NULL,
    UNIQUE (uuid_administrative_division, name)
);

CREATE TABLE tourism_region (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_tourism_region UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(150) NOT NULL,
    slug VARCHAR(180) NOT NULL UNIQUE
);

CREATE TABLE adventurer_style (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_adventurer_style UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(80) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(80)
);

CREATE TABLE app_user (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_app_user UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_country UUID REFERENCES country (uuid_country),
    uuid_adventurer_style UUID REFERENCES adventurer_style (uuid_adventurer_style),
    name VARCHAR(150) NOT NULL CHECK (btrim(name) <> ''),
    email VARCHAR(254) NOT NULL,
    phone_number VARCHAR(16),
    photo_url TEXT,
    bio TEXT,
    notifications_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    email_verified_at TIMESTAMPTZ,
    phone_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deactivated_at TIMESTAMPTZ,
    CHECK (email = btrim(email) AND email <> ''),
    CHECK (phone_number IS NULL OR phone_number ~ '^\+[1-9][0-9]{7,14}$'),
    CHECK (phone_number IS NOT NULL OR phone_verified_at IS NULL)
);

CREATE UNIQUE INDEX uq_app_user_email ON app_user (lower(email));
CREATE UNIQUE INDEX uq_app_user_phone_number ON app_user (phone_number) WHERE phone_number IS NOT NULL;

CREATE TABLE user_credential (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_user_credential UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_app_user UUID NOT NULL REFERENCES app_user (uuid_app_user),
    password_hash TEXT NOT NULL CHECK (btrim(password_hash) <> ''),
    password_changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (uuid_app_user)
);

CREATE TABLE social_identity (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_social_identity UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_app_user UUID NOT NULL REFERENCES app_user (uuid_app_user),
    provider VARCHAR(30) NOT NULL CHECK (provider IN ('google', 'apple')),
    provider_subject TEXT NOT NULL CHECK (btrim(provider_subject) <> ''),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (provider, provider_subject),
    UNIQUE (uuid_app_user, provider)
);

CREATE TABLE legal_document (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_legal_document UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    document_type VARCHAR(30) NOT NULL
        CHECK (document_type IN ('terms_of_use', 'privacy_policy')),
    version VARCHAR(30) NOT NULL,
    content_url TEXT NOT NULL,
    published_at TIMESTAMPTZ NOT NULL,
    UNIQUE (document_type, version)
);

CREATE TABLE document_acceptance (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_document_acceptance UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_app_user UUID NOT NULL REFERENCES app_user (uuid_app_user),
    uuid_legal_document UUID NOT NULL REFERENCES legal_document (uuid_legal_document),
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (uuid_app_user, uuid_legal_document)
);

CREATE TABLE campsite_category (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_campsite_category UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(100) NOT NULL UNIQUE,
    icon VARCHAR(80)
);

CREATE TABLE natural_setting (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_natural_setting UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(100) NOT NULL UNIQUE,
    icon VARCHAR(80)
);

CREATE TABLE amenity (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_amenity UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(100) NOT NULL UNIQUE,
    icon VARCHAR(80)
);

CREATE TABLE currency (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_currency UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    iso_code CHAR(3) NOT NULL UNIQUE,
    name VARCHAR(80) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    CHECK (iso_code ~ '^[A-Z]{3}$')
);

CREATE TABLE campsite (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_campsite UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_owner UUID NOT NULL REFERENCES app_user (uuid_app_user),
    uuid_campsite_category UUID NOT NULL REFERENCES campsite_category (uuid_campsite_category),
    uuid_city UUID REFERENCES city (uuid_city),
    uuid_currency UUID REFERENCES currency (uuid_currency),
    name VARCHAR(180) NOT NULL CHECK (btrim(name) <> ''),
    description TEXT,
    street_address VARCHAR(200),
    address_number VARCHAR(30),
    address_complement VARCHAR(150),
    neighborhood VARCHAR(120),
    postal_code VARCHAR(20),
    location_notes TEXT,
    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),
    altitude_meters NUMERIC(8,2),
    starting_price_per_night NUMERIC(12,2),
    status VARCHAR(30) NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'pending_review', 'published', 'rejected', 'archived')),
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    uuid_verified_by UUID REFERENCES app_user (uuid_app_user),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (latitude BETWEEN -90 AND 90),
    CHECK (longitude BETWEEN -180 AND 180),
    CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CHECK (starting_price_per_night IS NULL OR starting_price_per_night >= 0),
    CHECK ((starting_price_per_night IS NULL) = (uuid_currency IS NULL)),
    CHECK ((verified_at IS NULL) = (uuid_verified_by IS NULL)),
    CHECK (status <> 'published' OR (
        uuid_city IS NOT NULL AND street_address IS NOT NULL
        AND btrim(street_address) <> '' AND latitude IS NOT NULL
    ))
);

CREATE TABLE campsite_region (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_campsite_region UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_campsite UUID NOT NULL REFERENCES campsite (uuid_campsite),
    uuid_tourism_region UUID NOT NULL REFERENCES tourism_region (uuid_tourism_region),
    UNIQUE (uuid_campsite, uuid_tourism_region)
);

CREATE TABLE campsite_setting (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_campsite_setting UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_campsite UUID NOT NULL REFERENCES campsite (uuid_campsite),
    uuid_natural_setting UUID NOT NULL REFERENCES natural_setting (uuid_natural_setting),
    UNIQUE (uuid_campsite, uuid_natural_setting)
);

CREATE TABLE campsite_amenity (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_campsite_amenity UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_campsite UUID NOT NULL REFERENCES campsite (uuid_campsite),
    uuid_amenity UUID NOT NULL REFERENCES amenity (uuid_amenity),
    description TEXT,
    UNIQUE (uuid_campsite, uuid_amenity)
);

CREATE TABLE contact_type (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_contact_type UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(60) NOT NULL UNIQUE,
    icon VARCHAR(80)
);

CREATE TABLE campsite_contact (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_campsite_contact UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_campsite UUID NOT NULL REFERENCES campsite (uuid_campsite),
    uuid_contact_type UUID NOT NULL REFERENCES contact_type (uuid_contact_type),
    value TEXT NOT NULL CHECK (btrim(value) <> ''),
    verified_at TIMESTAMPTZ,
    UNIQUE (uuid_campsite, uuid_contact_type)
);

CREATE TABLE campsite_photo (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_campsite_photo UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_campsite UUID NOT NULL REFERENCES campsite (uuid_campsite),
    file_url TEXT NOT NULL CHECK (btrim(file_url) <> ''),
    description VARCHAR(250),
    sort_order SMALLINT NOT NULL CHECK (sort_order BETWEEN 1 AND 9),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (uuid_campsite, sort_order)
);

CREATE TABLE favorite (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_favorite UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_app_user UUID NOT NULL REFERENCES app_user (uuid_app_user),
    uuid_campsite UUID NOT NULL REFERENCES campsite (uuid_campsite),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (uuid_app_user, uuid_campsite)
);

CREATE TABLE camping_method (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_camping_method UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(100) NOT NULL UNIQUE,
    icon VARCHAR(80)
);

CREATE TABLE review (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_review UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_app_user UUID NOT NULL REFERENCES app_user (uuid_app_user),
    uuid_campsite UUID NOT NULL REFERENCES campsite (uuid_campsite),
    uuid_camping_method UUID REFERENCES camping_method (uuid_camping_method),
    rating NUMERIC(2,1) NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL CHECK (char_length(btrim(comment)) BETWEEN 50 AND 1000),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'published', 'hidden')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (uuid_app_user, uuid_campsite)
);

CREATE TABLE review_highlight (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_review_highlight UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name VARCHAR(100) NOT NULL UNIQUE,
    icon VARCHAR(80)
);

CREATE TABLE review_highlight_selection (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_review_highlight_selection UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_review UUID NOT NULL REFERENCES review (uuid_review),
    uuid_review_highlight UUID NOT NULL REFERENCES review_highlight (uuid_review_highlight),
    UNIQUE (uuid_review, uuid_review_highlight)
);

CREATE TABLE review_photo (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_review_photo UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_review UUID NOT NULL REFERENCES review (uuid_review),
    file_url TEXT NOT NULL CHECK (btrim(file_url) <> ''),
    description VARCHAR(250),
    sort_order SMALLINT NOT NULL CHECK (sort_order BETWEEN 1 AND 3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (uuid_review, sort_order)
);

CREATE TABLE notification (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_notification UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    title VARCHAR(180) NOT NULL CHECK (btrim(title) <> ''),
    message TEXT NOT NULL CHECK (btrim(message) <> ''),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_notification (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid_user_notification UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    uuid_notification UUID NOT NULL REFERENCES notification (uuid_notification),
    uuid_app_user UUID NOT NULL REFERENCES app_user (uuid_app_user),
    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMPTZ,
    UNIQUE (uuid_app_user, uuid_notification),
    CHECK (read_at IS NULL OR read_at >= received_at)
);

CREATE INDEX ix_country_continent ON country (uuid_continent);
CREATE INDEX ix_app_user_country ON app_user (uuid_country);
CREATE INDEX ix_app_user_adventurer_style ON app_user (uuid_adventurer_style);
CREATE INDEX ix_document_acceptance_legal_document ON document_acceptance (uuid_legal_document);
CREATE INDEX ix_campsite_owner ON campsite (uuid_owner);
CREATE INDEX ix_campsite_campsite_category ON campsite (uuid_campsite_category);
CREATE INDEX ix_campsite_city ON campsite (uuid_city);
CREATE INDEX ix_campsite_currency ON campsite (uuid_currency);
CREATE INDEX ix_campsite_verified_by ON campsite (uuid_verified_by);
CREATE INDEX ix_campsite_contact_contact_type ON campsite_contact (uuid_contact_type);
CREATE INDEX ix_favorite_campsite ON favorite (uuid_campsite);
CREATE INDEX ix_review_camping_method ON review (uuid_camping_method);
CREATE INDEX ix_review_highlight_selection_review_highlight ON review_highlight_selection (uuid_review_highlight);
CREATE INDEX ix_user_notification_notification ON user_notification (uuid_notification);
CREATE INDEX ix_campsite_region_tourism_region ON campsite_region (uuid_tourism_region, uuid_campsite);
CREATE INDEX ix_campsite_setting_natural_setting ON campsite_setting (uuid_natural_setting, uuid_campsite);
CREATE INDEX ix_campsite_amenity_amenity ON campsite_amenity (uuid_amenity, uuid_campsite);

CREATE INDEX ix_campsite_published ON campsite (created_at DESC) WHERE status = 'published';
CREATE INDEX ix_review_campsite_status ON review (uuid_campsite, status, created_at DESC);
CREATE INDEX ix_user_notification_recent ON user_notification (uuid_app_user, received_at DESC);
CREATE INDEX ix_user_notification_unread ON user_notification (uuid_app_user, received_at DESC) WHERE read_at IS NULL;

CREATE VIEW vw_campsite_review_summary AS
SELECT c.uuid_campsite, COUNT(r.uuid_review) AS review_count,
       ROUND(AVG(r.rating), 2) AS average_rating
FROM campsite c
LEFT JOIN review r ON r.uuid_campsite = c.uuid_campsite AND r.status = 'published'
GROUP BY c.uuid_campsite;

CREATE VIEW vw_country_campsite_summary AS
SELECT co.uuid_country, COUNT(c.uuid_campsite) AS campsite_count
FROM country co
LEFT JOIN administrative_division ad ON ad.uuid_country = co.uuid_country
LEFT JOIN city ci ON ci.uuid_administrative_division = ad.uuid_administrative_division
LEFT JOIN campsite c ON c.uuid_city = ci.uuid_city AND c.status = 'published'
GROUP BY co.uuid_country;

CREATE VIEW vw_user_notification AS
SELECT un.uuid_user_notification, un.uuid_app_user, n.uuid_notification,
       n.title, n.message, un.received_at, un.read_at, (un.read_at IS NOT NULL) AS is_read
FROM user_notification un
JOIN notification n ON n.uuid_notification = un.uuid_notification;

-- Reassert the restricted application's DML grants, including the new objects.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA kampive TO kampive_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA kampive TO kampive_app;

COMMIT;
