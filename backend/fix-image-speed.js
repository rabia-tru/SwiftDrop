/**
 * Speed + coverage fix for menu images:
 * 1. Every Unsplash URL gets size/format params (?w=400&h=300&fit=crop&q=70)
 *    so the CDN serves ~30KB crops instead of full 2-5MB originals — this is
 *    why the menu was loading so slowly.
 * 2. The one local-URL item (http://192.168.100.x/...) gets a proper https
 *    image so nothing renders as a fallback icon.
 * 3. Business logos are resized from 800px to 400px crops.
 * Idempotent: params appended only if absent.
 */
const { Client } = require('pg');
const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: '0000',
  database: 'delivery_tracker',
});

const SIZE_PARAMS = '?w=400&h=300&fit=crop&auto=format&q=70';
const LOGO_PARAMS = '?w=400&h=200&fit=crop&auto=format&q=70';
const FALLBACK_IMAGE =
  'https://images.unsplash.com/photo-1568901346375-23c9450c58cd' + SIZE_PARAMS;

function addParams(url, params) {
  if (!url) return url;
  if (url.includes('images.unsplash.com') && !url.includes('?')) {
    return url + params;
  }
  return url;
}

(async () => {
  await client.connect();

  // 1. Menu items: append size params to plain Unsplash URLs
  const menus = await client.query(
    `SELECT id, "imageUrl" FROM menu_items WHERE "imageUrl" LIKE '%images.unsplash.com%' AND "imageUrl" NOT LIKE '%?%'`,
  );
  for (const row of menus.rows) {
    const fixed = addParams(row.imageUrl, SIZE_PARAMS);
    await client.query(`UPDATE menu_items SET "imageUrl" = $1 WHERE id = $2`, [fixed, row.id]);
  }
  console.log(`menu items resized: ${menus.rowCount}`);

  // 2. Menu items with local http URLs → replace with a proper https image
  const local = await client.query(
    `UPDATE menu_items SET "imageUrl" = $1 WHERE "imageUrl" LIKE 'http://%' OR "imageUrl" LIKE '%localhost%' OR "imageUrl" LIKE '%192.168%' RETURNING name`,
    [FALLBACK_IMAGE],
  );
  console.log(`local-URL items fixed: ${local.rowCount}`, local.rows.map((r) => r.name).join(', '));

  // 3. Business logos: 800px → 400px crop
  const logos = await client.query(
    `SELECT id, "logoUrl" FROM businesses WHERE "logoUrl" LIKE '%images.unsplash.com%' AND "logoUrl" NOT LIKE '%?%'`,
  );
  for (const row of logos.rows) {
    const fixed = addParams(row.logoUrl, LOGO_PARAMS);
    await client.query(`UPDATE businesses SET "logoUrl" = $1 WHERE id = $2`, [fixed, row.id]);
  }
  console.log(`logos resized: ${logos.rowCount}`);

  // 4. Sanity: how many items still lack a valid https image?
  const bad = await client.query(
    `SELECT count(*) FROM menu_items WHERE "imageUrl" IS NULL OR "imageUrl" = '' OR NOT ("imageUrl" LIKE 'https://%')`,
  );
  console.log(`items still without valid https image: ${bad.rows[0].count}`);

  await client.end();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
