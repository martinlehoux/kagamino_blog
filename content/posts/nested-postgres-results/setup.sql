CREATE TABLE accommodations (
    id serial PRIMARY KEY,
    name text NOT NULL,
    default_price numeric(10, 2) NOT NULL
);

INSERT INTO accommodations (name, default_price)
SELECT
    CONCAT('accommodation_', generate_series) AS name,
    TRUNC(RANDOM() * 100 + 200) AS default_price
FROM GENERATE_SERIES(1, 10000);

CREATE TABLE overrides (
    id serial PRIMARY KEY,
    accommodation_id integer NOT NULL REFERENCES accommodations (id),
    date date NOT NULL,
    price numeric(10, 2) NOT NULL
);
ALTER TABLE overrides ADD constraint unique_dates UNIQUE (
    accommodation_id, date
);
INSERT INTO overrides (accommodation_id, date, price) SELECT
    (generate_series / 100) + 1 AS accommodation_id,
    '2025-01-01'::date + (generate_series % 100) * '3 days'::interval AS date,
    TRUNC(RANDOM() * 100 + 200) AS price
FROM GENERATE_SERIES(1, 999999);
