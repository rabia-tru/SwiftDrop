-- One-off cleanup: menu items whose imageUrl is missing or not a plausible
-- Unsplash photo URL (typos like "bsnsjejdjej" from manual testing) render
-- as grey boxes in the app. Give them a category-appropriate real photo.
UPDATE menu_items SET "imageUrl" = CASE
  WHEN category ILIKE '%drink%' OR category ILIKE '%shake%' OR category ILIKE '%beverage%'
    THEN 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=600&h=450&fit=crop&auto=format&q=75'
  WHEN category ILIKE '%dessert%' OR category ILIKE '%bakery%' OR category ILIKE '%sweet%'
    THEN 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600&h=450&fit=crop&auto=format&q=75'
  WHEN category ILIKE '%side%' OR category ILIKE '%snack%' OR category ILIKE '%starter%'
    THEN 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=600&h=450&fit=crop&auto=format&q=75'
  ELSE
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&h=450&fit=crop&auto=format&q=75'
END
WHERE "imageUrl" IS NULL
   OR "imageUrl" = ''
   OR "imageUrl" NOT LIKE 'https://images.unsplash.com/photo-%';

-- Report what's left
SELECT COUNT(*)::int AS remaining_bad FROM menu_items
WHERE "imageUrl" NOT LIKE 'https://images.unsplash.com/photo-%';
