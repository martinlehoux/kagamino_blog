CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name varchar(255) NOT NULL,
  description text,
  price numeric(10,2) NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW()
);

INSERT INTO products (name, description, price)
SELECT concat('product_', n), 'This is a product description.', trunc(random() * 1000 + 1)
FROM generate_series(1, 10000) as n; 

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  order_date DATE NOT NULL,
  customer_name TEXT NOT NULL,
  product_id INTEGER NOT NULL REFERENCES products(id)
);

INSERT INTO orders (order_date, customer_name, product_id)
SELECT now(), concat('customer_', n), floor(random() * 10000) + 1
FROM generate_series(1, 1000000) as n;

CREATE TABLE reviews (
  id SERIAL PRIMARY KEY,
  review_date TIMESTAMP NOT NULL,
  comment TEXT NOT NULL,
  product_id INTEGER NOT NULL REFERENCES products(id)
);

INSERT INTO reviews (review_date, comment, product_id)
SELECT now(), concat('Comment for review #', n), floor(random() * 10000) + 1
FROM generate_series(1, 100000) as n;

CREATE INDEX reviews_product_id_idx ON reviews (product_id);
CREATE INDEX orders_product_id_idx ON orders (product_id);
