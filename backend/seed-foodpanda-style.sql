-- SwiftDrop: FoodPanda-style seed data — all cuisines, full menus, verified images
-- Password for every seeded business: password123
-- Safe to re-run: deletes previous seed rows first.

-- 1. Clean previous seed
DELETE FROM menu_items WHERE "businessId" IN (SELECT id FROM businesses WHERE email LIKE '%@swiftdrop.pk');
DELETE FROM businesses WHERE email LIKE '%@swiftdrop.pk';

-- 2. Businesses — every major cuisine, Lahore coordinates
INSERT INTO businesses (name, phone, email, password, category, address, latitude, longitude, "logoUrl", description, "openingHours", "isOpen", "isActive") VALUES
-- Fast Food & Burgers
('Burger Lab', '03001112201', 'burgerlab@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Fast Food', 'Gulberg III, Lahore', 31.5155, 74.3436, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&h=400&fit=crop&auto=format&q=70', 'Gourmet smash burgers & loaded fries', '11:00 - 02:00', true, true),
('McDonald''s Style', '03001112202', 'mcdstyle@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Fast Food', 'MM Alam Road, Lahore', 31.5215, 74.3485, 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=800&h=400&fit=crop&auto=format&q=70', 'Classic burgers, fries & shakes', '09:00 - 01:00', true, true),
('Fried Chicken Co', '03001112203', 'friedchicken@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Fast Food', 'Johar Town, Lahore', 31.4670, 74.2860, 'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=800&h=400&fit=crop&auto=format&q=70', 'Crispy fried chicken & wings', '11:00 - 03:00', true, true),
-- Pizza
('Pizza Boulevard', '03001112204', 'pizzaboulevard@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Pizza', 'DHA Phase 5, Lahore', 31.4697, 74.4100, 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&h=400&fit=crop&auto=format&q=70', 'Wood-fired pizzas & garlic bread', '12:00 - 02:00', true, true),
('Pizza Hub', '03001112205', 'pizzahub@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Pizza', 'Model Town, Lahore', 31.4830, 74.3260, 'https://images.unsplash.com/photo-1571997478779-2adcbbe9ab2f?w=800&h=400&fit=crop&auto=format&q=70', 'Cheesy slices & party deals', '12:00 - 01:00', true, true),
-- Pakistani / Desi
('Karahi King', '03001112206', 'karahiking@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Pakistani', 'Old Anarkali, Lahore', 31.5497, 74.3140, 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=800&h=400&fit=crop&auto=format&q=70', 'Chicken & mutton karahi, handi, BBQ', '12:00 - 02:00', true, true),
('Biryani House', '03001112207', 'biryanihouse@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Pakistani', 'Garden Town, Lahore', 31.5120, 74.3290, 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=800&h=400&fit=crop&auto=format&q=70', 'Sindhi & Bombay biryani specialists', '11:00 - 23:00', true, true),
('Nihari Nights', '03001112208', 'niharinights@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Pakistani', 'Lakshmi Chowk, Lahore', 31.5560, 74.3230, 'https://images.unsplash.com/photo-1594751543129-6701ad444259?w=800&h=400&fit=crop&auto=format&q=70', 'Slow-cooked nihari & paye since 1985', '17:00 - 04:00', true, true),
('BBQ Tonight', '03001112209', 'bbqtonight@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'BBQ', 'Liberty Market, Lahore', 31.5105, 74.3450, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&h=400&fit=crop&auto=format&q=70', 'Chargha, seekh kabab & malai boti', '18:00 - 02:00', true, true),
-- Chinese & Pan-Asian
('Wok & Roll', '03001112210', 'wokandroll@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Chinese', 'Y Block, DHA Lahore', 31.5010, 74.4010, 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&h=400&fit=crop&auto=format&q=70', 'Manchurian, chowmein & sizzling plates', '12:00 - 23:30', true, true),
('Ramen Republic', '03001112211', 'ramenrepublic@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Pan Asian', 'Gulberg II, Lahore', 31.5180, 74.3390, 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800&h=400&fit=crop&auto=format&q=70', 'Ramen bowls, gyoza & bao buns', '13:00 - 23:00', true, true),
('Sushi Express', '03001112212', 'sushiexpress@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Pan Asian', 'Packages Mall, Lahore', 31.5300, 74.3570, 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800&h=400&fit=crop&auto=format&q=70', 'Fresh sushi rolls & ramen', '12:00 - 23:00', true, true),
-- Rolls, Shawarma & Wraps
('Roll Junction', '03001112213', 'rolljunction@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Rolls', 'Township, Lahore', 31.4720, 74.3080, 'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=800&h=400&fit=crop&auto=format&q=70', 'Kathi rolls, paratha wraps & shawarma', '13:00 - 03:00', true, true),
('Shawarma Shack', '03001112214', 'shawarmashack@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Shawarma', 'Faisal Town, Lahore', 31.4980, 74.3210, 'https://images.unsplash.com/photo-1562967914-608f82629710?w=800&h=400&fit=crop&auto=format&q=70', 'Arabian shawarma & zinger wraps', '14:00 - 03:00', true, true),
-- Breakfast
('Halwa Puri House', '03001112215', 'halwapuri@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Breakfast', 'Walled City, Lahore', 31.5820, 74.3230, 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&h=400&fit=crop&auto=format&q=70', 'Halwa puri nashta & chai', '06:00 - 12:00', true, true),
('Omelette Corner', '03001112216', 'omelettecorner@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Breakfast', 'Askari 10, Lahore', 31.5330, 74.3640, 'https://images.unsplash.com/photo-1437418747212-8d9709afab22?w=800&h=400&fit=crop&auto=format&q=70', 'Omelettes, parathas & french toast', '07:00 - 13:00', true, true),
-- Cafe & Desserts
('Chai Wala Cafe', '03001112217', 'chaiwala@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Cafe', 'Chairing Cross, Lahore', 31.5480, 74.3320, 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=800&h=400&fit=crop&auto=format&q=70', 'Doodh patti, club sandwich & snacks', '09:00 - 23:00', true, true),
('Sweet Tooth Desserts', '03001112218', 'sweettooth@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Desserts', 'Barki Market, Lahore', 31.5560, 74.3740, 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=800&h=400&fit=crop&auto=format&q=70', 'Sundaes, brownies & shakes', '14:00 - 02:00', true, true),
('Bakery Lane', '03001112219', 'bakerylane@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Bakery', 'Ferozepur Road, Lahore', 31.4930, 74.3160, 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=800&h=400&fit=crop&auto=format&q=70', 'Fresh cakes, pastries & savouries', '08:00 - 22:00', true, true),
-- Healthy
('Green Bowl', '03001112220', 'greenbowl@swiftdrop.pk', '$2b$10$0LrAKD6Z/sThfArIFSsmAu/jq7KLfl8VV2hQ1J9udCVox4DgrqDfS', 'Healthy', 'Gulberg III, Lahore', 31.5160, 74.3420, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&h=400&fit=crop&auto=format&q=70', 'Salads, wraps & protein bowls', '10:00 - 22:00', true, true);

-- 3. Menus (verified Unsplash images; prices in PKR)
INSERT INTO menu_items ("businessId", name, description, price, "imageUrl", category, "isAvailable", "isFeatured", "preparationTime", tags)
SELECT b.id, v.name, v.description, v.price, v.img, v.category, true, v.feat, v.prep, v.tags
FROM businesses b
JOIN (VALUES
-- Burger Lab
('burgerlab@swiftdrop.pk','Smash Burger','Double smashed beef patty, cheddar, secret sauce',650,'https://images.unsplash.com/photo-1568901346375-23c9450c58cd','Burgers',true,15,'bestseller,burger'),
('burgerlab@swiftdrop.pk','Crispy Zinger Burger','Crispy fillet, mayo, lettuce, brioche bun',550,'https://images.unsplash.com/photo-1606755962773-d324e0a13086','Burgers',false,12,'zinger,burger'),
('burgerlab@swiftdrop.pk','Loaded Fries','Fries topped with cheese sauce & jalapenos',380,'https://images.unsplash.com/photo-1573080496219-bb080dd4f877','Sides',true,10,'fries,cheese'),
('burgerlab@swiftdrop.pk','Chicken Wings (6pc)','Buffalo or BBQ glazed wings',600,'https://images.unsplash.com/photo-1567620832903-9fc6debc209f','Sides',true,18,'wings'),
('burgerlab@swiftdrop.pk','Molten Chocolate Burger','Chocolate bun, beef patty, molten cheese',750,'https://images.unsplash.com/photo-1553979459-d2229ba7433b','Burgers',true,16,'special'),
('burgerlab@swiftdrop.pk','Peri Peri Burger','Grilled chicken, peri sauce, caramelized onions',580,'https://images.unsplash.com/photo-1521305916504-4a1121188589','Burgers',true,14,'spicy'),
-- McDonald''s Style
('mcdstyle@swiftdrop.pk','Big Mac Style','Double patty, special sauce, sesame bun',620,'https://images.unsplash.com/photo-1550547660-d9450f859349','Burgers',true,10,'classic'),
('mcdstyle@swiftdrop.pk','McChicken','Crispy chicken fillet with lettuce',480,'https://images.unsplash.com/photo-1606755962773-d324e0a13086','Burgers',true,9,'chicken'),
('mcdstyle@swiftdrop.pk','French Fries (Large)','Golden salted fries',250,'https://images.unsplash.com/photo-1573080496219-bb080dd4f877','Sides',true,7,'fries'),
('mcdstyle@swiftdrop.pk','McFlurry','Chocolate or Oreo swirl ice cream',320,'https://images.unsplash.com/photo-1563805042-7684c019e1cb','Desserts',true,5,'icecream'),
('mcdstyle@swiftdrop.pk','Cheeseburger','Juicy patty with melted cheese',350,'https://images.unsplash.com/photo-1568901346375-23c9450c58cd','Burgers',false,8,'classic'),
-- Fried Chicken Co
('friedchicken@swiftdrop.pk','Broasted Chicken (2pc)','Crispy pressure-fried broast with bun',540,'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58','Fried Chicken',true,20,'broast,bestseller'),
('friedchicken@swiftdrop.pk','Hot Wings (8pc)','Spicy tossed wings with dip',680,'https://images.unsplash.com/photo-1567620832903-9fc6debc209f','Fried Chicken',true,18,'wings,spicy'),
('friedchicken@swiftdrop.pk','Chicken Tenders (5pc)','Crispy strips with honey mustard',550,'https://images.unsplash.com/photo-1562967914-608f82629710','Fried Chicken',true,15,'tenders'),
('friedchicken@swiftdrop.pk','Popcorn Chicken','Bite-sized crispy chicken bucket',450,'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec','Fried Chicken',true,12,'snack'),
('friedchicken@swiftdrop.pk','Family Feast','8pc broast, fries, coleslaw & 1L drink',2100,'https://images.unsplash.com/photo-1544025162-d76694265947','Deals',true,30,'deal,family'),
-- Pizza Boulevard
('pizzaboulevard@swiftdrop.pk','Chicken Tikka Pizza (L)','Tikka chunks, onions, mozzarella',1250,'https://images.unsplash.com/photo-1513104890138-7c749659a591','Pizza',true,25,'bestseller,pizza'),
('pizzaboulevard@swiftdrop.pk','Pepperoni Pizza (M)','Classic pepperoni with extra cheese',1100,'https://images.unsplash.com/photo-1628840042765-356cda07504e','Pizza',true,22,'pepperoni'),
('pizzaboulevard@swiftdrop.pk','Fajita Sicilian (L)','Fajita chicken, peppers, olives',1300,'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38','Pizza',true,25,'pizza'),
('pizzaboulevard@swiftdrop.pk','BBQ Chicken Pizza (M)','Smoky BBQ chicken & onions',1150,'https://images.unsplash.com/photo-1571997478779-2adcbbe9ab2f','Pizza',true,22,'bbq'),
('pizzaboulevard@swiftdrop.pk','Garlic Bread Sticks','With cheese dip',350,'https://images.unsplash.com/photo-1619535860434-ba1d8fa12536','Sides',true,12,'garlic'),
-- Pizza Hub
('pizzahub@swiftdrop.pk','Malai Boti Pizza (M)','Creamy malai boti with cheese',1050,'https://images.unsplash.com/photo-1571997478779-2adcbbe9ab2f','Pizza',true,22,'pizza'),
('pizzahub@swiftdrop.pk','Chicken Supreme (L)','Loaded chicken, peppers, mushroom',1250,'https://images.unsplash.com/photo-1513104890138-7c749659a591','Pizza',true,25,'supreme'),
('pizzahub@swiftdrop.pk','Margherita (M)','Classic tomato & mozzarella',850,'https://images.unsplash.com/photo-1574071318508-1cdbab80d002','Pizza',true,18,'classic'),
('pizzahub@swiftdrop.pk','Pizza Rolls','Cheese-filled rolls, 8pc',480,'https://images.unsplash.com/photo-1601050690597-df0568f70950','Sides',true,14,'snack'),
-- Karahi King
('karahiking@swiftdrop.pk','Chicken Karahi (Half)','Desi ghee, tomato, green chilli',1100,'https://images.unsplash.com/photo-1596797038530-2c107229654b','Desi',true,35,'bestseller,karahi'),
('karahiking@swiftdrop.pk','Mutton Karahi (1kg)','Slow-cooked mutton with special masala',2400,'https://images.unsplash.com/photo-1631452180519-c014fe946bc7','Desi',true,50,'karahi,mutton'),
('karahiking@swiftdrop.pk','Chicken Handi','Creamy boneless handi',1050,'https://images.unsplash.com/photo-1631452180519-c014fe946bc7','Desi',true,30,'handi'),
('karahiking@swiftdrop.pk','Seekh Kabab (4pc)','Char-grilled minced beef kabab',600,'https://images.unsplash.com/photo-1603360946369-dc9bb6258143','BBQ',true,20,'kabab'),
('karahiking@swiftdrop.pk','Naan / Roghni Naan','Fresh tandoori naan',60,'https://images.unsplash.com/photo-1565557623262-b51c2513a641','Bread',true,5,'naan'),
('karahiking@swiftdrop.pk','Mutton White Karahi','Creamy white karahi special',2600,'https://images.unsplash.com/photo-1596797038530-2c107229654b','Desi',true,50,'special'),
-- Biryani House
('biryanihouse@swiftdrop.pk','Sindhi Chicken Biryani','Spicy layered biryani with aloo',450,'https://images.unsplash.com/photo-1633945274405-b6c8069047b0','Biryani',true,20,'bestseller,biryani'),
('biryanihouse@swiftdrop.pk','Bombay Beef Biryani','Mild Bombay-style beef biryani',480,'https://images.unsplash.com/photo-1563379071332-aa5547cb5ef7','Biryani',true,20,'biryani'),
('biryanihouse@swiftdrop.pk','Chicken Tikka Biryani','Biryani topped with tikka boti',580,'https://images.unsplash.com/photo-1589302168068-964664d93dc0','Biryani',true,25,'tikka'),
('biryanihouse@swiftdrop.pk','Raita & Salad','Fresh raita with kachumber',100,'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe','Sides',true,3,'side'),
('biryanihouse@swiftdrop.pk','Family Pack (4)','4 biryanis, raita, salad & drink',1750,'https://images.unsplash.com/photo-1589302168068-964664d93dc0','Deals',true,40,'deal'),
-- Nihari Nights
('niharinights@swiftdrop.pk','Maghaz Nihari','Special brain nihari with tarka',650,'https://images.unsplash.com/photo-1594751543129-6701ad444259','Desi',true,25,'nihari,special'),
('niharinights@swiftdrop.pk','Beef Nihari','Slow-cooked overnight beef shank',550,'https://images.unsplash.com/photo-1594751543129-6701ad444259','Desi',true,25,'bestseller,nihari'),
('niharinights@swiftdrop.pk','Paye (Siri Paye)','Traditional trotters stew',600,'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d','Desi',true,30,'paye'),
('niharinights@swiftdrop.pk','Kulcha','Fresh baked kulcha',80,'https://images.unsplash.com/photo-1565557623262-b51c2513a641','Bread',true,8,'bread'),
-- BBQ Tonight
('bbqtonight@swiftdrop.pk','Chicken Chargha (Full)','Deep-fried whole marinated chicken',1450,'https://images.unsplash.com/photo-1544025162-d76694265947','BBQ',true,45,'bestseller,chargha'),
('bbqtonight@swiftdrop.pk','Malai Boti (8pc)','Creamy melt-in-mouth chicken boti',850,'https://images.unsplash.com/photo-1555939594-58d7cb561ad1','BBQ',true,25,'boti'),
('bbqtonight@swiftdrop.pk','Seekh Kabab (6pc)','Char-grilled beef kababs',780,'https://images.unsplash.com/photo-1603360946369-dc9bb6258143','BBQ',true,25,'kabab'),
('bbqtonight@swiftdrop.pk','Behari Boti','Spicy thin beef boti strips',900,'https://images.unsplash.com/photo-1555939594-58d7cb561ad1','BBQ',true,25,'beef'),
-- Wok & Roll
('wokandroll@swiftdrop.pk','Chicken Manchurian','Crispy chicken in tangy gravy',750,'https://images.unsplash.com/photo-1603133872878-684f208fb84b','Chinese',true,25,'bestseller'),
('wokandroll@swiftdrop.pk','Chicken Chowmein','Stir-fried noodles with vegetables',650,'https://images.unsplash.com/photo-1555126634-323283e090fa','Chinese',true,20,'noodles'),
('wokandroll@swiftdrop.pk','Szechuan Chicken','Fiery szechuan tossed chicken',780,'https://images.unsplash.com/photo-1603133872878-684f208fb84b','Chinese',true,25,'spicy'),
('wokandroll@swiftdrop.pk','Egg Fried Rice','Wok-tossed rice with egg',450,'https://images.unsplash.com/photo-1512058564366-18510be2db19','Chinese',true,15,'rice'),
('wokandroll@swiftdrop.pk','Spring Rolls (4pc)','Crispy vegetable rolls',320,'https://images.unsplash.com/photo-1606525437679-037aca74a3e9','Starters',true,12,'starter'),
-- Ramen Republic
('ramenrepublic@swiftdrop.pk','Tonkotsu Ramen','Rich pork broth, chashu, egg',950,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624','Ramen',true,25,'bestseller,ramen'),
('ramenrepublic@swiftdrop.pk','Spicy Miso Ramen','Miso broth with chilli oil & chicken',880,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624','Ramen',true,25,'ramen,spicy'),
('ramenrepublic@swiftdrop.pk','Chicken Gyoza (6pc)','Pan-fried dumplings with ponzu',550,'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf','Starters',true,18,'gyoza'),
('ramenrepublic@swiftdrop.pk','Bao Buns (2pc)','Crispy chicken bao with slaw',480,'https://images.unsplash.com/photo-1590368746679-a403ce9c2b3f','Starters',true,15,'bao'),
-- Sushi Express
('sushiexpress@swiftdrop.pk','California Roll (8pc)','Crab stick, avocado, cucumber',850,'https://images.unsplash.com/photo-1579871494447-9811cf80d66c','Sushi',true,20,'sushi,bestseller'),
('sushiexpress@swiftdrop.pk','Spicy Tuna Roll','Tuna with spicy mayo',980,'https://images.unsplash.com/photo-1611143669185-af224c5e3252','Sushi',true,20,'sushi,spicy'),
('sushiexpress@swiftdrop.pk','Salmon Nigiri (4pc)','Fresh salmon over rice',1050,'https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56','Sushi',true,18,'salmon'),
('sushiexpress@swiftdrop.pk','Chicken Ramen','Comforting chicken ramen bowl',780,'https://images.unsplash.com/photo-1569718212165-3a8278d5f624','Ramen',true,22,'ramen'),
-- Roll Junction
('rolljunction@swiftdrop.pk','Chicken Kathi Roll','Egg-wrapped paratha, chicken tikka',380,'https://images.unsplash.com/photo-1585032226651-759b368d7246','Rolls',true,15,'bestseller,roll'),
('rolljunction@swiftdrop.pk','Beef Malai Roll','Creamy beef boti wrap',420,'https://images.unsplash.com/photo-1585032226651-759b368d7246','Rolls',true,15,'roll'),
('rolljunction@swiftdrop.pk','Paratha Roll (Cheese)','Double paratha with cheese & chutney',400,'https://images.unsplash.com/photo-1631452180519-c014fe946bc7','Rolls',true,15,'cheese'),
('rolljunction@swiftdrop.pk','French Fries','Crispy salted fries',220,'https://images.unsplash.com/photo-1573080496219-bb080dd4f877','Sides',true,8,'fries'),
-- Shawarma Shack
('shawarmashack@swiftdrop.pk','Arabian Shawarma','Classic chicken shawarma with garlic sauce',300,'https://images.unsplash.com/photo-1562967914-608f82629710','Shawarma',true,12,'bestseller,shawarma'),
('shawarmashack@swiftdrop.pk','Zinger Shawarma','Crispy zinger strips in khubz',380,'https://images.unsplash.com/photo-1606755962773-d324e0a13086','Shawarma',true,14,'zinger'),
('shawarmashack@swiftdrop.pk','Cheese Shawarma','Extra cheese with jalapenos',360,'https://images.unsplash.com/photo-1562967914-608f82629710','Shawarma',true,13,'cheese'),
('shawarmashack@swiftdrop.pk','Shawarma Platter','Open platter with fries & sauces',650,'https://images.unsplash.com/photo-1529006557810-274b9b2fc783','Platters',true,20,'platter'),
-- Halwa Puri House
('halwapuri@swiftdrop.pk','Halwa Puri (2 Person)','4 puri, halwa, channay & aloo bhujia',450,'https://images.unsplash.com/photo-1585937421612-70a008356fbe','Breakfast',true,15,'bestseller,breakfast'),
('halwapuri@swiftdrop.pk','Halwa Puri (Single)','2 puri with halwa & channay',250,'https://images.unsplash.com/photo-1585937421612-70a008356fbe','Breakfast',true,12,'breakfast'),
('halwapuri@swiftdrop.pk','Chai (Doodh Patti)','Kadak doodh patti',100,'https://images.unsplash.com/photo-1544787219-7f47ccb76574','Drinks',true,5,'chai'),
-- Omelette Corner
('omelettecorner@swiftdrop.pk','Cheese Omelette','3-egg omelette with cheese & toast',280,'https://images.unsplash.com/photo-1437418747212-8d9709afab22','Breakfast',true,10,'eggs'),
('omelettecorner@swiftdrop.pk','Paratha Roll Breakfast','Paratha, omelette & chai deal',300,'https://images.unsplash.com/photo-1631452180519-c014fe946bc7','Breakfast',true,12,'deal'),
('omelettecorner@swiftdrop.pk','French Toast','Brioche french toast with syrup',320,'https://images.unsplash.com/photo-1484723091739-30a097e8f929','Breakfast',true,10,'sweet'),
-- Chai Wala Cafe
('chaiwalacafe@swiftdrop.pk','Club Sandwich','Triple-layer chicken club with fries',480,'https://images.unsplash.com/photo-1528735602780-2552fd46c7af','Sandwiches',true,15,'bestseller'),
('chaiwalacafe@swiftdrop.pk','Doodh Patti Chai','Traditional kadak chai',120,'https://images.unsplash.com/photo-1544787219-7f47ccb76574','Drinks',true,6,'chai,bestseller'),
('chaiwalacafe@swiftdrop.pk','Grilled Cheese Sandwich','Three cheese melt',380,'https://images.unsplash.com/photo-1528735602780-2552fd46c7af','Sandwiches',true,12,'cheese'),
('chaiwalacafe@swiftdrop.pk','Masala Fries','Spice-tossed fries with dip',280,'https://images.unsplash.com/photo-1573080496219-bb080dd4f877','Sides',true,10,'fries'),
-- Sweet Tooth Desserts
('sweettooth@swiftdrop.pk','Belgian Chocolate Brownie','Warm fudge brownie with ice cream',550,'https://images.unsplash.com/photo-1606313564200-e75d5e30476c','Desserts',true,12,'bestseller,brownie'),
('sweettooth@swiftdrop.pk','Molten Lava Cake','Chocolate lava with vanilla scoop',600,'https://images.unsplash.com/photo-1563805042-7684c019e1cb','Desserts',true,15,'lava'),
('sweettooth@swiftdrop.pk','Oreo Shake','Thick cookies & cream shake',450,'https://images.unsplash.com/photo-1553787499-6f9133860278','Shakes',true,8,'shake'),
('sweettooth@swiftdrop.pk','Sundae Deluxe','Triple scoop with nuts & fudge',500,'https://images.unsplash.com/photo-1551024506-0bccd828d307','Desserts',true,8,'sundae'),
-- Bakery Lane
('bakerylane@swiftdrop.pk','Chocolate Fudge Cake (Slice)','Rich fudge layer cake',350,'https://images.unsplash.com/photo-1578985545062-69928b1d9587','Bakery',true,5,'cake'),
('bakerylane@swiftdrop.pk','Chicken Puff','Flaky puff with chicken filling',150,'https://images.unsplash.com/photo-1601050690597-df0568f70950','Savoury',true,8,'puff'),
('bakerylane@swiftdrop.pk','Red Velvet Cupcake','Cream cheese frosted cupcake',280,'https://images.unsplash.com/photo-1587668178277-295251f900ce','Bakery',true,5,'cupcake'),
('bakerylane@swiftdrop.pk','Donut (Glazed)','Classic glazed ring donut',200,'https://images.unsplash.com/photo-1551024601-bec78aea704b','Bakery',true,4,'donut'),
-- Green Bowl
('greenbowl@swiftdrop.pk','Grilled Chicken Salad','Quinoa, greens, grilled chicken, citrus',650,'https://images.unsplash.com/photo-1512621776951-a57141f2eefd','Salads',true,15,'healthy,bestseller'),
('greenbowl@swiftdrop.pk','Protein Power Bowl','Chicken, eggs, chickpeas, avocado',750,'https://images.unsplash.com/photo-1546069901-ba9599a7e63c','Bowls',true,15,'protein'),
('greenbowl@swiftdrop.pk','Garden Wrap','Whole-wheat wrap with grilled veggies',450,'https://images.unsplash.com/photo-1626700051175-6818013e1d4f','Wraps',true,12,'veggie'),
('greenbowl@swiftdrop.pk','Smoothie Bowl','Mixed berry smoothie with granola',520,'https://images.unsplash.com/photo-1590301157890-4810ed352733','Bowls',true,10,'smoothie')
) AS v(email, name, description, price, img, category, feat, prep, tags)
ON b.email = v.email;

-- 4. Done — summary
SELECT 'Businesses seeded: ' || count(*) FROM businesses WHERE email LIKE '%@swiftdrop.pk';
SELECT 'Menu items seeded: ' || count(*) FROM menu_items WHERE "businessId" IN (SELECT id FROM businesses WHERE email LIKE '%@swiftdrop.pk');
