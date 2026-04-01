-- =========================================
-- Access Pass System — schema.sql
-- PostgreSQL
-- =========================================

-- =========================
-- 1. Reference tables
-- =========================

CREATE TABLE IF NOT EXISTS user_role (
    role_id      BIGSERIAL PRIMARY KEY,
    role_name    VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS app_user (
    user_id       BIGSERIAL PRIMARY KEY,
    full_name     VARCHAR(150) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    role_id       BIGINT NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_app_user_role
        FOREIGN KEY (role_id)
        REFERENCES user_role(role_id)
);

CREATE TABLE IF NOT EXISTS pass_type (
    pass_type_id     BIGSERIAL PRIMARY KEY,
    pass_type_name   VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS status (
    status_id      BIGSERIAL PRIMARY KEY,
    status_code    VARCHAR(30) NOT NULL UNIQUE,
    status_name    VARCHAR(100) NOT NULL UNIQUE
);

-- =========================
-- 2. Main business table
-- =========================

CREATE TABLE IF NOT EXISTS pass_request (
    request_id           BIGSERIAL PRIMARY KEY,
    request_number       VARCHAR(30) NOT NULL UNIQUE,
    pass_type_id         BIGINT NOT NULL,
    initiator_id         BIGINT NOT NULL,
    current_status_id    BIGINT NOT NULL,
    visitor_full_name    VARCHAR(150) NOT NULL,
    visitor_document     VARCHAR(100),
    visit_date           DATE NOT NULL,
    comment              TEXT,
    rejection_reason     TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_pass_request_pass_type
        FOREIGN KEY (pass_type_id)
        REFERENCES pass_type(pass_type_id),

    CONSTRAINT fk_pass_request_initiator
        FOREIGN KEY (initiator_id)
        REFERENCES app_user(user_id),

    CONSTRAINT fk_pass_request_status
        FOREIGN KEY (current_status_id)
        REFERENCES status(status_id)
);

-- =========================
-- 3. Status history
-- =========================

CREATE TABLE IF NOT EXISTS request_status_history (
    history_id            BIGSERIAL PRIMARY KEY,
    request_id            BIGINT NOT NULL,
    from_status_id        BIGINT,
    to_status_id          BIGINT NOT NULL,
    changed_by_user_id    BIGINT NOT NULL,
    comment               TEXT,
    changed_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_request_status_history_request
        FOREIGN KEY (request_id)
        REFERENCES pass_request(request_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_request_status_history_from_status
        FOREIGN KEY (from_status_id)
        REFERENCES status(status_id),

    CONSTRAINT fk_request_status_history_to_status
        FOREIGN KEY (to_status_id)
        REFERENCES status(status_id),

    CONSTRAINT fk_request_status_history_changed_by
        FOREIGN KEY (changed_by_user_id)
        REFERENCES app_user(user_id)
);

-- =========================
-- 4. Indexes
-- =========================

CREATE INDEX IF NOT EXISTS idx_pass_request_initiator_id
    ON pass_request(initiator_id);

CREATE INDEX IF NOT EXISTS idx_pass_request_current_status_id
    ON pass_request(current_status_id);

CREATE INDEX IF NOT EXISTS idx_pass_request_visit_date
    ON pass_request(visit_date);

CREATE INDEX IF NOT EXISTS idx_pass_request_created_at
    ON pass_request(created_at);

CREATE INDEX IF NOT EXISTS idx_request_status_history_request_id
    ON request_status_history(request_id);

CREATE INDEX IF NOT EXISTS idx_request_status_history_changed_at
    ON request_status_history(changed_at);

-- =========================
-- 5. Trigger: auto-update updated_at
-- =========================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_updated_at_pass_request ON pass_request;

CREATE TRIGGER trg_set_updated_at_pass_request
BEFORE UPDATE ON pass_request
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- =========================
-- 6. Trigger: rejection_reason required for REJECTED
-- =========================

CREATE OR REPLACE FUNCTION validate_rejection_reason()
RETURNS TRIGGER AS $$
DECLARE
    v_status_code VARCHAR(30);
BEGIN
    SELECT status_code
    INTO v_status_code
    FROM status
    WHERE status_id = NEW.current_status_id;

    IF v_status_code = 'REJECTED'
       AND (NEW.rejection_reason IS NULL OR BTRIM(NEW.rejection_reason) = '') THEN
        RAISE EXCEPTION 'rejection_reason is required when status is REJECTED';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_rejection_reason_pass_request ON pass_request;

CREATE TRIGGER trg_validate_rejection_reason_pass_request
BEFORE INSERT OR UPDATE ON pass_request
FOR EACH ROW
EXECUTE FUNCTION validate_rejection_reason();

-- =========================
-- 7. Seed data
-- =========================

INSERT INTO user_role (role_name)
VALUES
    ('Initiator'),
    ('Approver'),
    ('Security'),
    ('Administrator')
ON CONFLICT (role_name) DO NOTHING;

INSERT INTO pass_type (pass_type_name)
VALUES
    ('Employee'),
    ('Visitor'),
    ('Temporary')
ON CONFLICT (pass_type_name) DO NOTHING;

INSERT INTO status (status_code, status_name)
VALUES
    ('CREATED', 'Created'),
    ('IN_REVIEW', 'In Review'),
    ('APPROVED', 'Approved'),
    ('REJECTED', 'Rejected'),
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled')
ON CONFLICT (status_code) DO NOTHING;
