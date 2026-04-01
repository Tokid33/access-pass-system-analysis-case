-- =========================================
-- Access Pass System — sample_data.sql
-- Run after schema.sql
-- PostgreSQL
-- =========================================

BEGIN;

-- =========================
-- 1. Demo users
-- =========================

INSERT INTO app_user (full_name, email, role_id)
SELECT 'Ivan Petrov', 'ivan.petrov@example.com', r.role_id
FROM user_role r
WHERE r.role_name = 'Initiator'
ON CONFLICT (email) DO NOTHING;

INSERT INTO app_user (full_name, email, role_id)
SELECT 'Anna Smirnova', 'anna.smirnova@example.com', r.role_id
FROM user_role r
WHERE r.role_name = 'Approver'
ON CONFLICT (email) DO NOTHING;

INSERT INTO app_user (full_name, email, role_id)
SELECT 'Sergey Volkov', 'sergey.volkov@example.com', r.role_id
FROM user_role r
WHERE r.role_name = 'Security'
ON CONFLICT (email) DO NOTHING;

INSERT INTO app_user (full_name, email, role_id)
SELECT 'Maria Kozlova', 'maria.kozlova@example.com', r.role_id
FROM user_role r
WHERE r.role_name = 'Administrator'
ON CONFLICT (email) DO NOTHING;

-- =========================
-- 2. Demo requests
-- =========================

-- Request 1: just created
INSERT INTO pass_request (
    request_number,
    pass_type_id,
    initiator_id,
    current_status_id,
    visitor_full_name,
    visitor_document,
    visit_date,
    comment,
    created_at,
    updated_at
)
SELECT
    'REQ-2026-0001',
    pt.pass_type_id,
    u.user_id,
    s.status_id,
    'Alexey Sokolov',
    'Passport 4510 123456',
    DATE '2026-04-03',
    'Visitor expected for a business meeting',
    TIMESTAMPTZ '2026-04-01 09:00:00+03',
    TIMESTAMPTZ '2026-04-01 09:00:00+03'
FROM pass_type pt, app_user u, status s
WHERE pt.pass_type_name = 'Visitor'
  AND u.email = 'ivan.petrov@example.com'
  AND s.status_code = 'CREATED'
  AND NOT EXISTS (
      SELECT 1 FROM pass_request pr WHERE pr.request_number = 'REQ-2026-0001'
  );

-- Request 2: approved
INSERT INTO pass_request (
    request_number,
    pass_type_id,
    initiator_id,
    current_status_id,
    visitor_full_name,
    visitor_document,
    visit_date,
    comment,
    created_at,
    updated_at
)
SELECT
    'REQ-2026-0002',
    pt.pass_type_id,
    u.user_id,
    s.status_id,
    'Dmitry Orlov',
    'Passport 4511 654321',
    DATE '2026-04-04',
    'Contract signing appointment',
    TIMESTAMPTZ '2026-04-01 09:30:00+03',
    TIMESTAMPTZ '2026-04-01 11:00:00+03'
FROM pass_type pt, app_user u, status s
WHERE pt.pass_type_name = 'Visitor'
  AND u.email = 'ivan.petrov@example.com'
  AND s.status_code = 'APPROVED'
  AND NOT EXISTS (
      SELECT 1 FROM pass_request pr WHERE pr.request_number = 'REQ-2026-0002'
  );

-- Request 3: rejected
INSERT INTO pass_request (
    request_number,
    pass_type_id,
    initiator_id,
    current_status_id,
    visitor_full_name,
    visitor_document,
    visit_date,
    comment,
    rejection_reason,
    created_at,
    updated_at
)
SELECT
    'REQ-2026-0003',
    pt.pass_type_id,
    u.user_id,
    s.status_id,
    'Pavel Egorov',
    NULL,
    DATE '2026-04-05',
    'Courier delivery access request',
    'Visitor document is missing',
    TIMESTAMPTZ '2026-04-01 10:00:00+03',
    TIMESTAMPTZ '2026-04-01 10:40:00+03'
FROM pass_type pt, app_user u, status s
WHERE pt.pass_type_name = 'Temporary'
  AND u.email = 'ivan.petrov@example.com'
  AND s.status_code = 'REJECTED'
  AND NOT EXISTS (
      SELECT 1 FROM pass_request pr WHERE pr.request_number = 'REQ-2026-0003'
  );

-- Request 4: completed
INSERT INTO pass_request (
    request_number,
    pass_type_id,
    initiator_id,
    current_status_id,
    visitor_full_name,
    visitor_document,
    visit_date,
    comment,
    created_at,
    updated_at
)
SELECT
    'REQ-2026-0004',
    pt.pass_type_id,
    u.user_id,
    s.status_id,
    'Elena Morozova',
    'Passport 4512 777888',
    DATE '2026-04-02',
    'Interview candidate visit',
    TIMESTAMPTZ '2026-03-31 16:00:00+03',
    TIMESTAMPTZ '2026-04-02 18:15:00+03'
FROM pass_type pt, app_user u, status s
WHERE pt.pass_type_name = 'Visitor'
  AND u.email = 'ivan.petrov@example.com'
  AND s.status_code = 'COMPLETED'
  AND NOT EXISTS (
      SELECT 1 FROM pass_request pr WHERE pr.request_number = 'REQ-2026-0004'
  );

-- =========================
-- 3. Status history
-- =========================

-- REQ-2026-0001 : CREATED
INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    NULL,
    s_to.status_id,
    u.user_id,
    'Request created by initiator',
    TIMESTAMPTZ '2026-04-01 09:00:00+03'
FROM pass_request pr, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0001'
  AND s_to.status_code = 'CREATED'
  AND u.email = 'ivan.petrov@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 09:00:00+03'
  );

-- REQ-2026-0002 : CREATED -> IN_REVIEW -> APPROVED
INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    NULL,
    s_to.status_id,
    u.user_id,
    'Request created by initiator',
    TIMESTAMPTZ '2026-04-01 09:30:00+03'
FROM pass_request pr, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0002'
  AND s_to.status_code = 'CREATED'
  AND u.email = 'ivan.petrov@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 09:30:00+03'
  );

INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    s_from.status_id,
    s_to.status_id,
    u.user_id,
    'Request sent for review',
    TIMESTAMPTZ '2026-04-01 10:00:00+03'
FROM pass_request pr, status s_from, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0002'
  AND s_from.status_code = 'CREATED'
  AND s_to.status_code = 'IN_REVIEW'
  AND u.email = 'anna.smirnova@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 10:00:00+03'
  );

INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    s_from.status_id,
    s_to.status_id,
    u.user_id,
    'Request approved by approver',
    TIMESTAMPTZ '2026-04-01 11:00:00+03'
FROM pass_request pr, status s_from, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0002'
  AND s_from.status_code = 'IN_REVIEW'
  AND s_to.status_code = 'APPROVED'
  AND u.email = 'anna.smirnova@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 11:00:00+03'
  );

-- REQ-2026-0003 : CREATED -> IN_REVIEW -> REJECTED
INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    NULL,
    s_to.status_id,
    u.user_id,
    'Request created by initiator',
    TIMESTAMPTZ '2026-04-01 10:00:00+03'
FROM pass_request pr, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0003'
  AND s_to.status_code = 'CREATED'
  AND u.email = 'ivan.petrov@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 10:00:00+03'
  );

INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    s_from.status_id,
    s_to.status_id,
    u.user_id,
    'Request sent for review',
    TIMESTAMPTZ '2026-04-01 10:20:00+03'
FROM pass_request pr, status s_from, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0003'
  AND s_from.status_code = 'CREATED'
  AND s_to.status_code = 'IN_REVIEW'
  AND u.email = 'anna.smirnova@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 10:20:00+03'
  );

INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    s_from.status_id,
    s_to.status_id,
    u.user_id,
    'Rejected because visitor document is missing',
    TIMESTAMPTZ '2026-04-01 10:40:00+03'
FROM pass_request pr, status s_from, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0003'
  AND s_from.status_code = 'IN_REVIEW'
  AND s_to.status_code = 'REJECTED'
  AND u.email = 'anna.smirnova@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 10:40:00+03'
  );

-- REQ-2026-0004 : CREATED -> IN_REVIEW -> APPROVED -> COMPLETED
INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    NULL,
    s_to.status_id,
    u.user_id,
    'Request created by initiator',
    TIMESTAMPTZ '2026-03-31 16:00:00+03'
FROM pass_request pr, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0004'
  AND s_to.status_code = 'CREATED'
  AND u.email = 'ivan.petrov@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-03-31 16:00:00+03'
  );

INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    s_from.status_id,
    s_to.status_id,
    u.user_id,
    'Request sent for review',
    TIMESTAMPTZ '2026-04-01 09:00:00+03'
FROM pass_request pr, status s_from, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0004'
  AND s_from.status_code = 'CREATED'
  AND s_to.status_code = 'IN_REVIEW'
  AND u.email = 'anna.smirnova@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 09:00:00+03'
  );

INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    s_from.status_id,
    s_to.status_id,
    u.user_id,
    'Request approved by approver',
    TIMESTAMPTZ '2026-04-01 12:00:00+03'
FROM pass_request pr, status s_from, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0004'
  AND s_from.status_code = 'IN_REVIEW'
  AND s_to.status_code = 'APPROVED'
  AND u.email = 'anna.smirnova@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-01 12:00:00+03'
  );

INSERT INTO request_status_history (
    request_id,
    from_status_id,
    to_status_id,
    changed_by_user_id,
    comment,
    changed_at
)
SELECT
    pr.request_id,
    s_from.status_id,
    s_to.status_id,
    u.user_id,
    'Pass issued and request completed',
    TIMESTAMPTZ '2026-04-02 18:15:00+03'
FROM pass_request pr, status s_from, status s_to, app_user u
WHERE pr.request_number = 'REQ-2026-0004'
  AND s_from.status_code = 'APPROVED'
  AND s_to.status_code = 'COMPLETED'
  AND u.email = 'sergey.volkov@example.com'
  AND NOT EXISTS (
      SELECT 1
      FROM request_status_history h
      WHERE h.request_id = pr.request_id
        AND h.to_status_id = s_to.status_id
        AND h.changed_at = TIMESTAMPTZ '2026-04-02 18:15:00+03'
  );

COMMIT;
