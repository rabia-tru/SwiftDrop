/**
 * Seed FoodPanda-style dummy restaurants with real food images.
 * Usage: node seed-restaurants.js
 * Safe to re-run: checks by email before inserting.
 */
const { Client } = require('pg');
const bcrypt = require('bcrypt');

const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: '0000',
  database: 'delivery_tracker',
});

// Real Unsplash food photo IDs (free images, hotlinked)
const IMG = (id, w = 800) =>
  `https://images.unsplash.com/${id}?w=${w}&h=${Math.round((w * 2) / 3)}&fit=crop&auto=format&q=70`;

const restaurants = [
  {
    name: 'Karahi King',
    email: 'karahi@swiftdrop.pk', phone: '03001110001',
    category: 'Desi', address: 'Main Boulevard, Gulberg III, Lahore',
    logo: IMG('photo-1585937421612-70a008356fbe'),
    hours: '11:00 AM - 1:00 AM',
    menu: [
      { name: 'Chicken Karahi (Half)', price: 850, cat: 'Karahi', time: 25, feat: true,
        desc: 'Half kg chicken karahi cooked in desi ghee with tomatoes, green chillies and fresh coriander.',
        img: IMG('photo-1596560548464-f010549b84d7', 400) },
      { name: 'Chicken Karahi (Full)', price: 1600, cat: 'Karahi', time: 35,
        desc: 'Full kg chicken karahi — the classic Pakistani family feast.',
        img: IMG('photo-1596560548464-f010549b84d7', 400) },
      { name: 'Mutton Karahi (Half)', price: 1900, cat: 'Karahi', time: 40,
        desc: 'Tender mutton karahi slow-cooked with spices.',
        img: IMG('photo-1596797038530-2c107229654b', 400) },
      { name: 'Chicken Biryani', price: 350, cat: 'Biryani', time: 15, feat: true,
        desc: 'Fragrant basmati rice layered with spicy chicken, served with raita.',
        img: IMG('photo-1563379091339-03b21ab4a4f8', 400) },
      { name: 'Beef Biryani', price: 400, cat: 'Biryani', time: 15,
        desc: 'Rich beef biryani with saffron rice and salad.',
        img: IMG('photo-1589302168068-964664d93dc0', 400) },
      { name: 'Seekh Kabab (4 pcs)', price: 550, cat: 'BBQ', time: 20,
        desc: 'Juicy minced beef seekh kababs straight off the charcoal grill.',
        img: IMG('photo-1603360946369-dc9bb6258143', 400) },
      { name: 'Malai Boti', price: 650, cat: 'BBQ', time: 20,
        desc: 'Creamy marinated chicken chunks, melt-in-mouth soft.',
        img: IMG('photo-1555939594-58d7cb561ad1', 400) },
      { name: 'Tandoori Roti', price: 30, cat: 'Bread', time: 5,
        desc: 'Fresh whole-wheat roti from the tandoor.',
        img: IMG('photo-1608198093002-ad4e005484ec', 400) },
      { name: 'Garlic Naan', price: 80, cat: 'Bread', time: 5,
        desc: 'Buttery garlic naan, perfect with karahi.',
        img: IMG('photo-1619535860434-ba1d8fa12536', 400) },
    ],
  },
  {
    name: 'Burger Lab',
    email: 'burgerlab@swiftdrop.pk', phone: '03001110002',
    category: 'Fast Food', address: 'Y Block, DHA Phase 3, Lahore',
    logo: IMG('photo-1571091718767-18b5b1457add'),
    hours: '12:00 PM - 2:00 AM',
    menu: [
      { name: 'Smoky BBQ Bacon Burger', price: 790, cat: 'Burgers', time: 18, feat: true,
        desc: 'Double beef patty, crispy bacon, cheddar, smoked BBQ sauce and caramelized onions.',
        img: IMG('photo-1568901346375-23c9450c58cd', 400) },
      { name: 'Zinger Crunch Burger', price: 590, cat: 'Burgers', time: 15,
        desc: 'Crispy fried chicken fillet, lettuce, mayo and a fiery kick.',
        img: IMG('photo-1606755962773-d324e0a13086', 400) },
      { name: 'Classic Cheese Burger', price: 490, cat: 'Burgers', time: 12,
        desc: 'Juicy beef patty with melted cheese, pickles and secret sauce.',
        img: IMG('photo-1550547660-d9450f859349', 400) },
      { name: 'Mushroom Swiss Burger', price: 690, cat: 'Burgers', time: 18,
        desc: 'Beef patty topped with sautéed mushrooms and swiss cheese.',
        img: IMG('photo-1520072959219-c595e6cdc07a', 400) },
      { name: 'Loaded Fries', price: 350, cat: 'Sides', time: 10, feat: true,
        desc: 'Crispy fries loaded with cheese sauce, jalapeños and chicken chunks.',
        img: IMG('photo-1573080496219-bb080dd4f877', 400) },
      { name: 'Chicken Wings (6 pcs)', price: 480, cat: 'Sides', time: 15,
        desc: 'Spicy buffalo wings with ranch dip.',
        img: IMG('photo-1608039755401-742074f0548d', 400) },
      { name: 'Onion Rings', price: 250, cat: 'Sides', time: 8,
        desc: 'Golden crispy onion rings served with dip.',
        img: IMG('photo-1639024471283-0c3b1c0a0b1c', 400) },
      { name: 'Chocolate Thick Shake', price: 320, cat: 'Drinks', time: 7,
        desc: 'Thick & creamy chocolate shake topped with whipped cream.',
        img: IMG('photo-1541658016709-82535e94bc69', 400) },
    ],
  },
  {
    name: 'Pizza Boulevard',
    email: 'pizzaboul@swiftdrop.pk', phone: '03001110003',
    category: 'Pizza', address: 'MM Alam Road, Gulberg, Lahore',
    logo: IMG('photo-1513104890138-7c749659a591'),
    hours: '12:00 PM - 1:00 AM',
    menu: [
      { name: 'Chicken Fajita (Large)', price: 1150, cat: 'Pizza', time: 25, feat: true,
        desc: 'Loaded with chicken fajita chunks, capsicum, onions and mozzarella.',
        img: IMG('photo-1565299624946-b28f40a0ae38', 400) },
      { name: 'Pepperoni Feast (Large)', price: 1250, cat: 'Pizza', time: 25,
        desc: 'Double pepperoni with extra cheese on our signature sauce.',
        img: IMG('photo-1534307989820-d1a6d0a72d63', 400) },
      { name: 'Creamy Tikka (Medium)', price: 850, cat: 'Pizza', time: 20,
        desc: 'Desi-style chicken tikka pizza with creamy white sauce base.',
        img: IMG('photo-1574071318508-1cdbab80d002', 400) },
      { name: 'Margherita (Medium)', price: 650, cat: 'Pizza', time: 18,
        desc: 'Classic tomato, mozzarella and fresh basil.',
        img: IMG('photo-1604382354936-07c5d9983bd3', 400) },
      { name: 'Garlic Bread Sticks', price: 280, cat: 'Sides', time: 10,
        desc: 'Oven-baked sticks brushed with garlic butter, served with cheese dip.',
        img: IMG('photo-1619535860434-ba1d8fa12536', 400) },
      { name: 'Chicken Wings (8 pcs)', price: 590, cat: 'Sides', time: 15,
        desc: 'Hot & spicy wings tossed in buffalo sauce.',
        img: IMG('photo-1608039755401-742074f0548d', 400) },
      { name: 'Coke 1.5L', price: 150, cat: 'Drinks', time: 2,
        desc: 'Chilled Coca-Cola bottle.',
        img: IMG('photo-1554866585-cd94860890b7', 400) },
    ],
  },
  {
    name: 'Chai Wala Cafe',
    email: 'chaiwala@swiftdrop.pk', phone: '03001110004',
    category: 'Cafe', address: 'Café Corner, Liberty Market, Lahore',
    logo: IMG('photo-1554118811-1e0d58224f24'),
    hours: '8:00 AM - 12:00 AM',
    menu: [
      { name: 'Doodh Patti Chai', price: 120, cat: 'Drinks', time: 8, feat: true,
        desc: 'The real deal — slow-brewed milk tea served in a traditional cup.',
        img: IMG('photo-1571934811356-5cc061b6821f', 400) },
      { name: 'Kashmiri Chai', price: 200, cat: 'Drinks', time: 10,
        desc: 'Pink pink tea topped with crushed nuts.',
        img: IMG('photo-1556679343-c7306c1976bc', 400) },
      { name: 'Cappuccino', price: 350, cat: 'Drinks', time: 6,
        desc: 'Double-shot espresso with velvety steamed milk.',
        img: IMG('photo-1572442388796-11668a67e53d', 400) },
      { name: 'Club Sandwich', price: 450, cat: 'Snacks', time: 12, feat: true,
        desc: 'Triple-layered grilled sandwich with chicken, egg and cheese.',
        img: IMG('photo-1528735602780-2552fd46c7af', 400) },
      { name: 'Chicken Paratha Roll', price: 380, cat: 'Snacks', time: 12,
        desc: 'Flaky paratha wrapped around spicy chicken with garlic mayo.',
        img: IMG('photo-1637163423772-06c7d91f2bb5', 400) },
      { name: 'Chocolate Fudge Cake', price: 320, cat: 'Desserts', time: 5,
        desc: 'Rich slice of moist chocolate fudge cake.',
        img: IMG('photo-1578985545062-69928b1d9587', 400) },
      { name: 'Cheese Cake Slice', price: 420, cat: 'Desserts', time: 5,
        desc: 'New York style baked cheese cake with berry compote.',
        img: IMG('photo-1533134242443-d4fd215305ad', 400) },
    ],
  },
  {
    name: 'Biryani House',
    email: 'biryanihouse@swiftdrop.pk', phone: '03001110005',
    category: 'Desi', address: 'Barkat Market, Garden Town, Lahore',
    logo: IMG('photo-1631515243349-e0cb75fb8d3a'),
    hours: '11:00 AM - 11:00 PM',
    menu: [
      { name: 'Chicken Biryani (Single)', price: 380, cat: 'Biryani', time: 12, feat: true,
        desc: 'Aromatic basmati, tender chicken, served with raita & salad.',
        img: IMG('photo-1563379091339-03b21ab4a4f8', 400) },
      { name: 'Chicken Biryani (Family Pack)', price: 1400, cat: 'Biryani', time: 25,
        desc: 'Serves 4 — with 4 raita boxes and salad.',
        img: IMG('photo-1589302168068-964664d93dc0', 400) },
      { name: 'Beef Biryani (Single)', price: 430, cat: 'Biryani', time: 12,
        desc: 'Slow-cooked beef layered with fragrant rice.',
        img: IMG('photo-1631515243349-e0cb75fb8d3a', 400) },
      { name: 'Chicken Pulao', price: 350, cat: 'Biryani', time: 12,
        desc: 'Yakhni pulao with tender chicken and whole spices.',
        img: IMG('photo-1596797038530-2c107229654b', 400) },
      { name: 'Raita', price: 60, cat: 'Sides', time: 2,
        desc: 'Fresh whisked yogurt with mint.',
        img: IMG('photo-1571212515416-fef01fc43637', 400) },
      { name: 'Kheer', price: 180, cat: 'Desserts', time: 5,
        desc: 'Traditional rice pudding with cardamom and nuts.',
        img: IMG('photo-1571167530149-c72f2b6b4a83', 400) },
    ],
  },
  {
    name: 'Wok & Roll',
    email: 'woknroll@swiftdrop.pk', phone: '03001110006',
    category: 'Chinese', address: 'Avari Mall, Gulberg II, Lahore',
    logo: IMG('photo-1504674900247-0877df9cc836'),
    hours: '12:00 PM - 11:30 PM',
    menu: [
      { name: 'Chicken Chowmein', price: 550, cat: 'Chinese', time: 18, feat: true,
        desc: 'Stir-fried noodles with shredded chicken and vegetables.',
        img: IMG('photo-1562967914-608f82629710', 400) },
      { name: 'Chicken Manchurian', price: 680, cat: 'Chinese', time: 20,
        desc: 'Crispy chicken balls in sweet & sour manchurian gravy.',
        img: IMG('photo-1604908176997-125f25cc6f3d', 400) },
      { name: 'Egg Fried Rice', price: 420, cat: 'Chinese', time: 15,
        desc: 'Wok-tossed rice with eggs and spring onions.',
        img: IMG('photo-1603133872878-684f208fb84b', 400) },
      { name: 'Chilli Chicken Dry', price: 720, cat: 'Chinese', time: 20,
        desc: 'Spicy dry chilli chicken with bell peppers.',
        img: IMG('photo-1626082927389-6cd097cdc6ec', 400) },
      { name: 'Chicken Shashlik', price: 750, cat: 'Chinese', time: 22,
        desc: 'Grilled chicken skewers with tangy shashlik sauce and rice.',
        img: IMG('photo-1529042410759-befb1204b468', 400) },
      { name: 'Hot & Sour Soup', price: 280, cat: 'Chinese', time: 10,
        desc: 'Classic spicy-sour soup with chicken and vegetables.',
        img: IMG('photo-1547592166-23ac45744acd', 400) },
    ],
  },
];

async function main() {
  await client.connect();
  console.log('Connected to DB. Seeding restaurants...');
  const hash = await bcrypt.hash('password123', 10);

  for (const r of restaurants) {
    const existing = await client.query('SELECT id FROM businesses WHERE email = $1', [r.email]);
    if (existing.rows.length > 0) {
      console.log(`- ${r.name}: already exists (skipped)`);
      continue;
    }

    const res = await client.query(
      `INSERT INTO businesses (name, phone, email, password, category, address, "logoUrl", "openingHours", "isOpen", "isActive")
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,true) RETURNING id`,
      [r.name, r.phone, r.email, hash, r.category, r.address, r.logo, r.hours]
    );
    const bizId = res.rows[0].id;

    for (const m of r.menu) {
      await client.query(
        `INSERT INTO menu_items (name, description, price, "imageUrl", category, "isAvailable", "isFeatured", "preparationTime", "businessId")
         VALUES ($1,$2,$3,$4,$5,true,$6,$7,$8)`,
        [m.name, m.desc, m.price, m.img, m.cat, !!m.feat, m.time, bizId]
      );
    }
    console.log(`+ ${r.name}: ${r.menu.length} menu items added`);
  }

  const total = await client.query('SELECT count(*) FROM businesses');
  const items = await client.query('SELECT count(*) FROM menu_items');
  console.log(`Done! Total businesses: ${total.rows[0].count}, total menu items: ${items.rows[0].count}`);
  await client.end();
}

main().catch((e) => { console.error(e); process.exit(1); });
