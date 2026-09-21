-- Fix dead Unsplash image URLs (verified 404) with working alternatives
UPDATE menu_items SET "imageUrl" = 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&h=267&fit=crop&auto=format&q=70' WHERE "imageUrl" LIKE '%photo-1637163423772-06c7d91f2bb5%'; -- Chicken Paratha Roll
UPDATE menu_items SET "imageUrl" = 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&h=267&fit=crop&auto=format&q=70' WHERE "imageUrl" LIKE '%photo-1534307989820-d1a6d0a72d63%'; -- Pepperoni Feast
UPDATE menu_items SET "imageUrl" = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=267&fit=crop&auto=format&q=70' WHERE "imageUrl" LIKE '%photo-1520072959219-c595e6cdc07a%'; -- Mushroom Swiss Burger
UPDATE menu_items SET "imageUrl" = 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&h=267&fit=crop&auto=format&q=70' WHERE "imageUrl" LIKE '%photo-1639024471283-0c3b1c0a0b1c%'; -- Onion Rings
UPDATE menu_items SET "imageUrl" = 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&h=267&fit=crop&auto=format&q=70' WHERE "imageUrl" LIKE '%photo-1571167530149-c72f2b6b4a83%'; -- Kheer -> dessert
