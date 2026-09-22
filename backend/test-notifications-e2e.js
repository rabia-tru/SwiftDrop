/**
 * End-to-end live verification of the notification pipeline.
 * Connects a fake rider socket (same namespace /tracking and room-join the
 * app uses), triggers a real order-ready push via the HTTP API (business
 * accepts + marks ready), and checks the rider's socket receives the
 * events the app actually listens to. Cleans up all test data at the end.
 */
const { io } = require('socket.io-client');
const { Client } = require('pg');
const bcrypt = require('bcrypt');

const BASE = 'http://localhost:3000';
const client = new Client({
  host: 'localhost', port: 5432, user: 'postgres', password: '0000', database: 'delivery_tracker',
});

const j = async (path, opts = {}) => {
  const r = await fetch(`${BASE}${path}`, {
    ...opts,
    headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
  });
  const text = await r.text();
  let body;
  try { body = JSON.parse(text); } catch { body = text.slice(0, 300); }
  if (!r.ok) throw new Error(`${opts.method || 'GET'} ${path} -> ${r.status}: ${typeof body === 'string' ? body : JSON.stringify(body).slice(0, 300)}`);
  return body;
};
const post = (p, b, t) => j(p, { method: 'POST', body: JSON.stringify(b), headers: t ? { Authorization: `Bearer ${t}` } : {} });
const patch = (p, t, b) => j(p, { method: 'PATCH', body: b ? JSON.stringify(b) : undefined, headers: t ? { Authorization: `Bearer ${t}` } : {} });

async function main() {
  const suffix = String(Date.now()).slice(-8);
  const bEmail = `notiftest.${suffix}@test.local`;
  const rEmail = `notiftest.rider.${suffix}@test.local`;

  await client.connect();

  // 1. Seed business + rider directly in DB
  const hash = bcrypt.hashSync('test1234', 10);
  await client.query(
    `INSERT INTO businesses (id, name, phone, email, password, category, address, "isOpen", "isActive", "createdAt")
     VALUES (gen_random_uuid(), $1, '${'033' + suffix.slice(-8)}', $2, $3, 'restaurant', 'Test Street 1', true, true, now())`,
    [`NotifTest Kitchen ${suffix}`, bEmail, hash],
  );
  const biz = await client.query(`SELECT id, name FROM businesses WHERE email = $1`, [bEmail]);
  const business = biz.rows[0];

  await client.query(
    `INSERT INTO riders (id, name, email, phone, password, "vehicleType", "isActive", status, "createdAt")
     VALUES (gen_random_uuid(), $1, $2, $3, $4, 'bike', true, 'offline', now())`,
    [`NotifTest Rider ${suffix}`, rEmail, `032${suffix.slice(-8)}`, hash],
  );
  const riderRow = await client.query(`SELECT id FROM riders WHERE email = $1`, [rEmail]);
  const riderId = riderRow.rows[0].id;

  // 2. Login via real API for tokens
  const blogin = await post('/api/business/login', { email: bEmail, password: 'test1234' });
  const btoken = blogin.token || blogin.access_token || blogin.accessToken;
  const rlogin = await post('/api/auth/rider/login', { email: rEmail, password: 'test1234' });
  const rtoken = rlogin.token || rlogin.access_token || rlogin.accessToken;
  if (!rtoken) throw new Error(`rider login returned no token: ${JSON.stringify(rlogin).slice(0, 200)}`);

  // sanity: rider /me works with token
  const me = await j('/api/riders/me', { headers: { Authorization: `Bearer ${rtoken}` } });
  console.log(`rider /me OK (id=${me.id || riderId})`);

  // 3. Rider socket — SAME namespace (/tracking) and SAME room-join the app uses
  const events = [];
  const socket = io(`${BASE}/tracking`, {
    transports: ['websocket'],
    auth: { token: rtoken, riderId },
  });
  for (const ev of ['order:newAssigned', 'order:newAvailable', 'rider:orderUpdate', 'order:status', 'order:update']) {
    socket.on(ev, (d) => events.push({ ev, d }));
  }
  socket.on('connect', () => {
    socket.emit('watchRider', { riderId }); // app joins its own private room
  });
  await new Promise((res, rej) => {
    socket.on('connect', res);
    socket.on('connect_error', (e) => rej(new Error(`socket connect_error: ${e.message}`)));
    setTimeout(() => rej(new Error('socket connect timeout (8s)')), 8000);
  });
  await new Promise((r) => setTimeout(r, 400));
  console.log('rider socket connected to /tracking & joined rider room');

  // 4. Create a real pending order
  const ord = await client.query(
    `INSERT INTO orders (id, "businessId", "customerName", "customerPhone", "pickupAddress", "pickupLat", "pickupLng", "dropAddress", "dropLat", "dropLng", status, fare, items, "createdAt")
     VALUES (gen_random_uuid(), $1, 'NotifTest Customer', '03001234567', 'Kitchen No 12', 31.5204, 74.3587, 'Test Street 1', 31.5304, 74.3687, 'pending', 500,
     $2::jsonb, now()) RETURNING id`,
    [String(business.id), JSON.stringify([{ name: 'Test Burger', qty: 1, price: 500 }])],
  );
  const orderId = ord.rows[0].id;

  // 5. Business accepts -> explicitly assign MY test rider -> marks ready.
  // (Explicit assign because auto-assign would hand the order to whichever
  // online rider the backend finds first.)
  await patch(`/api/orders/${orderId}/business-accept`, btoken);
  await patch(`/api/orders/${orderId}/assign`, btoken, { riderId });
  await new Promise((r) => setTimeout(r, 800));
  await patch(`/api/orders/${orderId}/ready`, btoken);

  // 6. Wait for socket events
  await new Promise((r) => setTimeout(r, 3000));
  const got = events.map((e) => e.ev);
  console.log('=== RIDER SOCKET EVENTS RECEIVED ===');
  console.log(got.length ? [...new Set(got)].join(', ') : '(none)');
  const assigned = events.find((e) => e.ev === 'order:newAssigned');
  if (assigned) {
    console.log('=== order:newAssigned PAYLOAD ===');
    console.log(JSON.stringify(assigned.d, null, 2));
  }

  const row = await client.query(`SELECT status, "readyNotifiedAt" FROM orders WHERE id = $1`, [orderId]);
  console.log(`=== DB STATE === status=${row.rows[0].status} readyNotifiedAt=${row.rows[0].readyNotifiedAt ? 'SET' : 'null'}`);

  // The exact checks the app needs: the assigned ping AND the ready ping
  // (the app shows "New Order Assigned" vs "Food is Ready" based on the flag)
  const gotAssigned = events.some((e) => e.ev === 'order:newAssigned' && e.d?.orderId === orderId);
  const readyPing = events.some((e) => e.ev === 'order:newAssigned' && e.d?.orderId === orderId && e.d?.readyForPickup === true);
  const allNewAssigned = events.filter((e) => e.ev === 'order:newAssigned');
  console.log(`order:newAssigned events received: ${allNewAssigned.length} (flags: ${allNewAssigned.map((e) => e.d?.readyForPickup).join(', ')})`);
  console.log(gotAssigned && readyPing
    ? '\n✅ NOTIFICATION PIPELINE WORKS END-TO-END (assignment ping + ready ping both received)'
    : `\n❌ PIPELINE BROKEN: gotAssigned=${gotAssigned} readyPing=${readyPing}`);

  // 7. Cleanup all test data
  socket.disconnect();
  await client.query(`DELETE FROM orders WHERE id = $1`, [orderId]);
  await client.query(`DELETE FROM riders WHERE id = $1`, [riderId]);
  await client.query(`DELETE FROM businesses WHERE id = $1`, [business.id]);
  console.log('(test data cleaned up)');
  await client.end();
  process.exit(gotAssigned && readyPing ? 0 : 1);
}

main().catch(async (e) => {
  console.error('❌ TEST FAILED:', e.message);
  try { await client.end(); } catch {}
  process.exit(1);
});
