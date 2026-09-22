/**
 * One-off cleanup: the leftover test business "Pizza hub" (lowercase h) has
 * no logo and duplicates the real "Pizza Hub". Give it a proper logo so no
 * restaurant card in the app shows an empty image. Idempotent.
 */
const { Client } = require('pg');
const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: '0000',
  database: 'delivery_tracker',
});

const LOGO =
  'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&h=400&fit=crop&auto=format&q=70';

(async () => {
  await client.connect();
  const res = await client.query(
    `UPDATE businesses SET "logoUrl" = $1 WHERE "logoUrl" IS NULL OR "logoUrl" = '' RETURNING name`,
    [LOGO],
  );
  console.log(`updated ${res.rowCount} business(es):`, res.rows.map((r) => r.name).join(', ') || '(none)');
  await client.end();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
