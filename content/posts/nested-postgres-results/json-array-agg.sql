SELECT
    accommodation_id,
    json_agg(json_build_object(
        'date', date,
        'price', price
    )) AS daily_configs
FROM
    overrides
WHERE '[2025-07-01,2025-07-08)'::daterange
@> date
GROUP BY overrides.accommodation_id
