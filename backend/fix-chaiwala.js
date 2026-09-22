/**
 * Fix Chai Wala Cafe menu — the seed SQL referenced 'chaiwalacafe@swiftdrop.pk'
 * while the business was inserted as 'chaiwala@swiftdrop.pk', so its 4 items
 * were silently skipped. Adds them if missing.
 */
const { Client } = require('pg');

const client = new Client({
  host: 'localhost', port: 5432, user: 'postgres', password: '0000', database: 'delivery_tracker',
});

const items = [
  ['Club Sandwich', 'Triple-layer chicken club with fries', 480, 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af', 'Sandwiches', true, 15],
  ['Doodh Patti Chai', 'Traditional kadak chai', 120, 'https://images.unsplash.com/photo-1544787219-7f47ccb76574', 'Drinks', true, 6],
  ['Grilled Cheese Sandwich', 'Three cheese melt', 380, 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af', 'Sandwiches', true, 12],
  ['Masala Fries', 'Spice-tossed fries with dip', 280, 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877', 'Sides', true, 10],
];

async function main() {
  await client.connect();
  const b = await client.query("SELECT id FROM businesses WHERE email = 'chaiwala@swiftdrop.pk'");
  if (b.rows.length === 0) { console.log('Chai Wala Cafe business not found'); await client.end(); return; }
  const bizId = b.rows[0].id;
  for (const [name, desc, price, img, cat, feat, prep] of items) {
    const exists = await client.query(
      'SELECT 1 FROM menu_items WHERE "businessId"=$1 AND name=$2 LIMIT 1',
      [bizId, name]
    );
    if (exists.rows.length > 0) continue;
    await client.query(
      `INSERT INTO menu_items ("businessId", name, description, price, "imageUrl", category, "isAvailable", "isFeatured", "preparationTime")
       VALUES ($1,$2,$3,$4,$5,$6,true,$7,$8)`,
      [bizId, name, desc, price, img, cat, feat, prep]
    );
  }
  const m = await client.query('SELECT count(*) FROM menu_items');
  console.log('menu_items total now:', m.rows[0].count);
  await client.end();
}

main().catch(e => { console.error('ERR', e.message); process.exit(1); });
