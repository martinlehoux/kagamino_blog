SELECT
    accommodation_id,
    array_agg((date, price)) AS daily_configs
FROM
    overrides
WHERE '[2025-07-01,2025-07-08)'::daterange
@> date
GROUP BY overrides.accommodation_id
