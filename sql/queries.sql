-- =========================================
-- Access Pass System — queries.sql
-- PostgreSQL
-- Demo analytical / operational queries
-- =========================================

-- =====================================================
-- Q1. Список всех заявок с текущим статусом и инициатором
-- =====================================================

SELECT
    pr.request_number,
    pt.pass_type_name,
    pr.visitor_full_name,
    pr.visit_date,
    s.status_code AS current_status_code,
    s.status_name AS current_status_name,
    u.full_name AS initiator_name,
    pr.created_at
FROM pass_request pr
JOIN pass_type pt
    ON pt.pass_type_id = pr.pass_type_id
JOIN status s
    ON s.status_id = pr.current_status_id
JOIN app_user u
    ON u.user_id = pr.initiator_id
ORDER BY pr.created_at DESC;


-- =====================================================
-- Q2. Карточка одной заявки
-- =====================================================

SELECT
    pr.request_id,
    pr.request_number,
    pt.pass_type_name,
    pr.visitor_full_name,
    pr.visitor_document,
    pr.visit_date,
    s.status_code AS current_status_code,
    s.status_name AS current_status_name,
    pr.comment,
    pr.rejection_reason,
    u.full_name AS initiator_name,
    u.email AS initiator_email,
    pr.created_at,
    pr.updated_at
FROM pass_request pr
JOIN pass_type pt
    ON pt.pass_type_id = pr.pass_type_id
JOIN status s
    ON s.status_id = pr.current_status_id
JOIN app_user u
    ON u.user_id = pr.initiator_id
WHERE pr.request_number = 'REQ-2026-0003';


-- =====================================================
-- Q3. История смены статусов по одной заявке
-- =====================================================

SELECT
    pr.request_number,
    s_from.status_code AS from_status_code,
    s_from.status_name AS from_status_name,
    s_to.status_code AS to_status_code,
    s_to.status_name AS to_status_name,
    au.full_name AS changed_by,
    h.comment,
    h.changed_at
FROM request_status_history h
JOIN pass_request pr
    ON pr.request_id = h.request_id
LEFT JOIN status s_from
    ON s_from.status_id = h.from_status_id
JOIN status s_to
    ON s_to.status_id = h.to_status_id
JOIN app_user au
    ON au.user_id = h.changed_by_user_id
WHERE pr.request_number = 'REQ-2026-0004'
ORDER BY h.changed_at;


-- =====================================================
-- Q4. Количество заявок по текущим статусам
-- =====================================================

SELECT
    s.status_code,
    s.status_name,
    COUNT(*) AS request_count
FROM pass_request pr
JOIN status s
    ON s.status_id = pr.current_status_id
GROUP BY
    s.status_code,
    s.status_name
ORDER BY request_count DESC, s.status_code;


-- =====================================================
-- Q5. Отклонённые заявки с причинами отклонения
-- =====================================================

SELECT
    pr.request_number,
    pr.visitor_full_name,
    pr.visit_date,
    pr.rejection_reason,
    u.full_name AS initiator_name,
    pr.updated_at
FROM pass_request pr
JOIN status s
    ON s.status_id = pr.current_status_id
JOIN app_user u
    ON u.user_id = pr.initiator_id
WHERE s.status_code = 'REJECTED'
ORDER BY pr.updated_at DESC;


-- =====================================================
-- Q6. Заявки конкретного инициатора
-- =====================================================

SELECT
    u.full_name AS initiator_name,
    pr.request_number,
    pr.visitor_full_name,
    pr.visit_date,
    s.status_code AS current_status,
    pr.created_at
FROM pass_request pr
JOIN app_user u
    ON u.user_id = pr.initiator_id
JOIN status s
    ON s.status_id = pr.current_status_id
WHERE u.email = 'ivan.petrov@example.com'
ORDER BY pr.created_at DESC;


-- =====================================================
-- Q7. Заявки на конкретную дату визита
-- =====================================================

SELECT
    pr.request_number,
    pr.visitor_full_name,
    pt.pass_type_name,
    s.status_code AS current_status,
    u.full_name AS initiator_name
FROM pass_request pr
JOIN pass_type pt
    ON pt.pass_type_id = pr.pass_type_id
JOIN status s
    ON s.status_id = pr.current_status_id
JOIN app_user u
    ON u.user_id = pr.initiator_id
WHERE pr.visit_date = DATE '2026-04-04'
ORDER BY pr.request_number;


-- =====================================================
-- Q8. Среднее количество часов от создания до последнего обновления
-- =====================================================

SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (pr.updated_at - pr.created_at)) / 3600.0)::numeric, 2) AS avg_processing_hours
FROM pass_request pr;


-- =====================================================
-- Q9. Сколько заявок создал каждый инициатор
-- =====================================================

SELECT
    u.full_name AS initiator_name,
    COUNT(*) AS requests_created
FROM pass_request pr
JOIN app_user u
    ON u.user_id = pr.initiator_id
GROUP BY u.full_name
ORDER BY requests_created DESC, initiator_name;


-- =====================================================
-- Q10. Последний статус по каждой заявке через историю
-- Проверка согласованности истории и current_status
-- =====================================================

WITH latest_history AS (
    SELECT
        h.request_id,
        h.to_status_id,
        h.changed_at,
        ROW_NUMBER() OVER (
            PARTITION BY h.request_id
            ORDER BY h.changed_at DESC, h.history_id DESC
        ) AS rn
    FROM request_status_history h
)
SELECT
    pr.request_number,
    s_current.status_code AS current_status_in_request,
    s_hist.status_code AS latest_status_in_history,
    lh.changed_at AS latest_history_changed_at
FROM pass_request pr
JOIN latest_history lh
    ON lh.request_id = pr.request_id
   AND lh.rn = 1
JOIN status s_current
    ON s_current.status_id = pr.current_status_id
JOIN status s_hist
    ON s_hist.status_id = lh.to_status_id
ORDER BY pr.request_number;


-- =====================================================
-- Q11. Заявки, которые ещё не завершены
-- =====================================================

SELECT
    pr.request_number,
    pr.visitor_full_name,
    s.status_code AS current_status,
    pr.visit_date,
    pr.created_at
FROM pass_request pr
JOIN status s
    ON s.status_id = pr.current_status_id
WHERE s.status_code NOT IN ('COMPLETED', 'CANCELLED')
ORDER BY pr.visit_date, pr.created_at;


-- =====================================================
-- Q12. Время прохождения заявки по этапам
-- =====================================================

SELECT
    pr.request_number,
    s_from.status_code AS from_status,
    s_to.status_code AS to_status,
    h.changed_at,
    LEAD(h.changed_at) OVER (
        PARTITION BY h.request_id
        ORDER BY h.changed_at
    ) AS next_changed_at
FROM request_status_history h
JOIN pass_request pr
    ON pr.request_id = h.request_id
LEFT JOIN status s_from
    ON s_from.status_id = h.from_status_id
JOIN status s_to
    ON s_to.status_id = h.to_status_id
ORDER BY pr.request_number, h.changed_at;
