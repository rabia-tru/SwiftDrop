/**
 * Add drinks to seeded restaurants so the customer "Drinks" filter has
 * enough items (chai alone was too thin). Idempotent.
 */
const { Client } = require('pg');
const client = new Client({ host: 'localhost', port: 5432, user: 'postgres', password: '0000', database: 'delivery_tracker' });

const drinks = [
  // [businessEmail, name, description, price, image, prepTime, featured]
  ['burgerlab@swiftdrop.pk', 'Coke 500ml', 'Chilled Coca-Cola can', 120, 'https://images.unsplash.com/photo-1554866585-cd94860890b7', 3, false],
  ['burgerlab@swiftdrop.pk', 'Chocolate Thick Shake', 'Thick & creamy shake with whipped cream', 320, 'https://images.unsplash.com/photo-1541658016709-82535e94bc69', 7, true],
  ['pizzaboulevard@swiftdrop.pk', 'Coke 1.5L', 'Chilled family-size bottle', 150, 'https://images.unsplash.com/photo-1554866585-cd94860890b7', 2, false],
  ['pizzaboulevard@swiftdrop.pk', 'Mint Margarita', 'Refreshing mint & lemon cooler', 280, 'https://images.unsplash.com/photo-1551538827-9c037cb4f32a', 6, true],
  ['karahiking@swiftdrop.pk', 'Lassi (Sweet)', 'Thick creamy sweet lassi', 220, 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f', 5, true],
  ['biryanihouse@swiftdrop.pk', 'Fresh Lime Soda', 'Lemon, soda & a pinch of black salt', 180, 'https://images.unsplash.com/photo-1621263764928-df1444c5e859', 4, false],
  ['wokandroll@swiftdrop.pk', 'Iced Lemon Tea', 'Chilled lemon iced tea', 250, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc', 5, false],
  ['chaiwala@swiftdrop.pk', 'Cappuccino', 'Double-shot espresso with steamed milk', 350, 'https://images.unsplash.com/photo-1572442388796-11668a67e53d', 6, true],
];

async function main() {
  await client.connect();
  let added = 0;
  for (const [email, name, desc, price, img, prep, feat] of drinks) {
    const b = await client.query('SELECT id FROM businesses WHERE email = $1', [email]);
    if (b.rows.length === 0) { console.log('skip (no biz):', email); continue; }
    const bizId = b.rows[0].id;
    const exists = await client.query('SELECT 1 FROM menu_items WHERE "businessId"=$1 AND name=$2 LIMIT 1', [bizId, name]);
    if (exists.rows.length > 0) continue;
    await client.query(
      `INSERT INTO menu_items ("businessId", name, description, price, "imageUrl", category, "isAvailable", "isFeatured", "preparationTime")
       VALUES ($1,$2,$3,$4,$5,'Drinks',true,$6,$7)`,
      [bizId, name, desc, price, img, feat, prep]
    );
    added++;
  }
  const m = await client.query("SELECT count(*) FROM menu_items WHERE category ILIKE '%drink%'");
  console.log('added:', added, '| drinks total:', m.rows[0].count);
  await client.end();
}

main().catch(e => { console.error('ERR', e.message); process.exit(1); });
