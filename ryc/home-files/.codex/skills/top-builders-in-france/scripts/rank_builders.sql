-- Best overall builder score per Paxel user. Output: email<TAB>score, score-desc.
-- Run with: psql ... -tA -F $'\t' -o /tmp/paxel_builders.tsv -f rank_builders.sql
-- NOTE: scans v3_results jsonb (3-35MB/row) -> slow (~1-2 min). Projects scalar only.
WITH scored AS (
  SELECT u.user_id, (v3_results->'overall'->>'score')::numeric AS score
  FROM uploads u
  WHERE u.status = 'complete'
    AND v3_results ? 'overall'
    AND (v3_results->'overall'->>'score') ~ '^[0-9.]+$'
),
best AS (SELECT user_id, max(score) AS score FROM scored GROUP BY user_id)
SELECT lower(us.email), b.score
FROM best b JOIN users us ON us.id = b.user_id
WHERE b.user_id IS NOT NULL
ORDER BY b.score DESC;
