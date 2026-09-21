const { Client } = require('pg');
const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: '0000',
  database: 'delivery_tracker'
});

async function run() {
  await client.connect();
  const bizRes = await client.query('SELECT * FROM businesses WHERE id = $1', ['db29a2a6-799f-492a-81a8-610a9e4522d1']);
  console.log('Business db29a2a6-799f-492a-81a8-610a9e4522d1:');
  console.log(bizRes.rows[0]);

  const itemsRes = await client.query('SELECT * FROM menu_items WHERE "businessId" = $1', ['db29a2a6-799f-492a-81a8-610a9e4522d1']);
  console.log('Menu items count:', itemsRes.rows.length);
  console.log(itemsRes.rows);

  await client.end();
}

run().catch(console.error);
