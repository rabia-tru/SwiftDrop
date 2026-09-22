-- Wipe ALL user data across every role (riders, customers, businesses)
-- plus everything that references them. Order matters for FK constraints.
-- Seed data (restaurants/menus from seed-foodpanda-style.sql) is ALSO
-- removed — run the seed scripts afterwards if you want the demo catalog back.

BEGIN;

-- Everything in one statement — CASCADE follows the FK graph so order
-- doesn't matter and no constraint blocks the wipe.
TRUNCATE chat_messages, location_logs, order_status_history, orders,
         menu_items, businesses, riders, customers CASCADE;

-- Reset any auto-increment/identity counters so new rows start clean
-- (safe no-op for UUID primary keys)
SELECT setval(pg_get_serial_sequence(t, c), 1, false)
FROM (VALUES ('riders','id'), ('customers','id'), ('businesses','id'),
             ('orders','id'), ('menu_items','id')) AS v(t, c)
WHERE pg_get_serial_sequence(t, c) IS NOT NULL;

COMMIT;
