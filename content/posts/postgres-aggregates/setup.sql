CREATE TABLE products(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL,
  description text,
  price numeric(10, 2) NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW()
);

INSERT INTO products(name, description, price)
SELECT
  CONCAT('product_', n),
  'This is a product description.',
  TRUNC(RANDOM() * 1000 + 1)
FROM
  GENERATE_SERIES(1, 10000) AS n;

CREATE TABLE orders(
  id serial PRIMARY KEY,
  order_date date NOT NULL,
  customer_name text NOT NULL,
  product_id integer NOT NULL REFERENCES products(id)
);

INSERT INTO orders(order_date, customer_name, product_id)
SELECT
  NOW(),
  CONCAT('customer_', n),
  FLOOR(RANDOM() * 10000) + 1
FROM
  GENERATE_SERIES(1, 1000000) AS n;

CREATE TABLE reviews(
  id serial PRIMARY KEY,
  review_date timestamp NOT NULL,
  comment text NOT NULL,
  product_id integer NOT NULL REFERENCES products(id)
);

INSERT INTO reviews(review_date, comment, product_id)
SELECT
  NOW(),
  CONCAT('Comment for review #', n),
  FLOOR(RANDOM() * 10000) + 1
FROM
  GENERATE_SERIES(1, 100000) AS n;

CREATE INDEX reviews_product_id_idx ON reviews(product_id);

CREATE INDEX orders_product_id_idx ON orders(product_id);

