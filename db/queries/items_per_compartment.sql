-- Number of items per compartment for every set (case).
-- Same result as the page /cases/compartments (CompartmentOverview).
--
--   boxes    boxes/bags (Box, Meshbag) that sit in the compartment
--   direct   items placed directly in the compartment
--   in_boxes items inside those boxes
--   total    direct + in_boxes
--
-- Compartments are the section item types (Case, Compartment); containers
-- themselves (Case, Compartment, Box, Meshbag) are never counted as items.
-- Items in no compartment are listed as "(not in a compartment)".
-- The last row of every set is its total (compartment IS NULL).
--
-- Usage: psql -d wink_development -f db/queries/items_per_compartment.sql

WITH it AS (
  SELECT i.id, i.name, i.case_id, i.location_item_id, t.name AS type,
         COALESCE(t.name IN ('Case', 'Compartment'), false)                 AS is_section,
         COALESCE(t.name IN ('Box', 'Meshbag'), false)                      AS is_bag,
         COALESCE(t.name IN ('Case', 'Compartment', 'Box', 'Meshbag'), false) AS is_container
  FROM items i
  LEFT JOIN item_types t ON t.id = i.item_type_id
  WHERE NOT i.deleted
),
per_compartment AS (
  SELECT s.case_id, s.type, s.name AS compartment,
         (SELECT count(*) FROM it c
           WHERE c.case_id = s.case_id AND c.location_item_id = s.id AND c.is_bag)        AS boxes,
         (SELECT count(*) FROM it c
           WHERE c.case_id = s.case_id AND c.location_item_id = s.id AND NOT c.is_container) AS direct,
         (SELECT count(*) FROM it c
            JOIN it b ON b.id = c.location_item_id AND b.is_bag
                     AND b.case_id = s.case_id AND b.location_item_id = s.id
           WHERE c.case_id = s.case_id AND NOT c.is_container)                            AS in_boxes
  FROM it s
  WHERE s.is_section
),
unplaced AS (
  SELECT c.case_id, NULL AS type, '(not in a compartment)' AS compartment,
         0::bigint AS boxes, count(*) AS direct, 0::bigint AS in_boxes
  FROM it c
  WHERE NOT c.is_container
    -- not directly in a compartment ...
    AND NOT EXISTS (SELECT 1 FROM it s
                    WHERE s.id = c.location_item_id AND s.case_id = c.case_id AND s.is_section)
    -- ... and not in a box that is in a compartment
    AND NOT EXISTS (SELECT 1 FROM it b JOIN it s ON s.id = b.location_item_id
                                                AND s.case_id = b.case_id AND s.is_section
                    WHERE b.id = c.location_item_id AND b.case_id = c.case_id AND b.is_bag)
  GROUP BY c.case_id
  HAVING count(*) > 0
),
rows AS (
  SELECT * FROM per_compartment
  UNION ALL
  SELECT * FROM unplaced
)
SELECT ca.name                          AS "set",
       ct.name                          AS set_type,
       r.compartment,
       sum(r.boxes)                     AS boxes,
       sum(r.direct)                    AS direct,
       sum(r.in_boxes)                  AS in_boxes,
       sum(r.direct + r.in_boxes)       AS total
FROM rows r
JOIN cases ca ON ca.id = r.case_id
LEFT JOIN case_types ct ON ct.id = ca.case_type_id
GROUP BY ROLLUP ((ca.id, ca.name, ct.name), (r.type, r.compartment))
HAVING ca.id IS NOT NULL                      -- no grand total over all sets
ORDER BY ca.name, ca.id, (r.compartment IS NULL), r.type NULLS LAST, r.compartment;
