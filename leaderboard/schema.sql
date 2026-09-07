CREATE TABLE IF NOT EXISTS entries (
  week_id TEXT NOT NULL,
  handle TEXT NOT NULL,
  maxed_total INTEGER NOT NULL DEFAULT 0,
  maxed_breakdown TEXT NOT NULL DEFAULT '{}',
  cost_usd_total REAL NOT NULL DEFAULT 0,
  cost_breakdown TEXT NOT NULL DEFAULT '{}',
  -- ISO 3166-1 Alpha-2 code Cloudflare derives from the submitter's IP at request time.
  country TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (week_id, handle)
);

CREATE INDEX IF NOT EXISTS idx_entries_week_maxed ON entries (week_id, maxed_total DESC);
CREATE INDEX IF NOT EXISTS idx_entries_week_cost ON entries (week_id, cost_usd_total DESC);

-- Best-effort per-IP throttle for the unauthenticated /submit endpoint.
CREATE TABLE IF NOT EXISTS submit_log (
  ip TEXT NOT NULL,
  ts INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_submit_log_ip_ts ON submit_log (ip, ts);
