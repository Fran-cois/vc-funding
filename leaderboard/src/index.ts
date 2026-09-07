export interface Env {
  DB: D1Database;
}

const MAX_HANDLE_LENGTH = 32;
const MAX_AGENTS = 8;
// ~33 possible 5-hour cycles per agent per week; capped generously above that as a sanity bound.
const MAX_COUNT_PER_AGENT = 60;
const MAX_COST_USD_PER_AGENT = 100_000;
const RATE_LIMIT_WINDOW_S = 3_600;
const RATE_LIMIT_MAX_SUBMITS = 20;
const DEFAULT_LEADERBOARD_LIMIT = 10;
const MAX_LEADERBOARD_LIMIT = 50;

function isoWeekId(date: Date): string {
  const target = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const dayNumber = (target.getUTCDay() + 6) % 7; // Monday = 0
  target.setUTCDate(target.getUTCDate() - dayNumber + 3); // nearest Thursday defines the ISO week/year
  const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
  const firstThursdayDayNumber = (firstThursday.getUTCDay() + 6) % 7;
  const week = 1 + Math.round(
    (target.getTime() - firstThursday.getTime()) / 86_400_000 / 7 + (firstThursdayDayNumber - dayNumber) / 7
  );
  return `${target.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

function sanitizeHandle(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  // eslint-disable-next-line no-control-regex -- stripping control characters is the point
  const trimmed = raw.replace(/[\u0000-\u001F\u007F]/g, "").trim();
  if (trimmed.length < 1 || trimmed.length > MAX_HANDLE_LENGTH) return null;
  return trimmed;
}

// Cloudflare's own geolocation of the request IP — never something the client sends or picks.
function sanitizeCountryCode(raw: string | undefined): string | null {
  if (!raw || !/^([A-Z]{2}|T1)$/.test(raw)) return null;
  return raw;
}

function sanitizeNumberMap(raw: unknown, maxValue: number): Record<string, number> | null {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) return null;
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length > MAX_AGENTS) return null;
  const result: Record<string, number> = {};
  for (const [key, value] of entries) {
    if (key.length < 1 || key.length > 40) return null;
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > maxValue) return null;
    result[key] = value;
  }
  return result;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function safeParseObject(json: string): unknown {
  try {
    return JSON.parse(json);
  } catch {
    return {};
  }
}

async function checkAndRecordRateLimit(env: Env, ip: string): Promise<boolean> {
  const nowSeconds = Math.floor(Date.now() / 1_000);
  await env.DB.prepare("DELETE FROM submit_log WHERE ts < ?").bind(nowSeconds - 86_400).run();

  const windowStart = nowSeconds - RATE_LIMIT_WINDOW_S;
  const countResult = await env.DB.prepare(
    "SELECT COUNT(*) as count FROM submit_log WHERE ip = ? AND ts > ?"
  )
    .bind(ip, windowStart)
    .first<{ count: number }>();

  if ((countResult?.count ?? 0) >= RATE_LIMIT_MAX_SUBMITS) {
    return false;
  }

  await env.DB.prepare("INSERT INTO submit_log (ip, ts) VALUES (?, ?)").bind(ip, nowSeconds).run();
  return true;
}

async function handleSubmit(request: Request, env: Env): Promise<Response> {
  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
  const allowed = await checkAndRecordRateLimit(env, ip);
  if (!allowed) {
    return jsonResponse({ error: "Rate limit exceeded, try again later" }, 429);
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }
  if (typeof payload !== "object" || payload === null) {
    return jsonResponse({ error: "Invalid body" }, 400);
  }
  const body = payload as Record<string, unknown>;

  const handle = sanitizeHandle(body.handle);
  if (!handle) {
    return jsonResponse({ error: "handle must be 1-32 characters" }, 400);
  }
  const maxedCounts = sanitizeNumberMap(body.maxedCounts ?? {}, MAX_COUNT_PER_AGENT);
  if (!maxedCounts) {
    return jsonResponse({ error: "invalid maxedCounts" }, 400);
  }
  const costsUSD = sanitizeNumberMap(body.costsUSD ?? {}, MAX_COST_USD_PER_AGENT);
  if (!costsUSD) {
    return jsonResponse({ error: "invalid costsUSD" }, 400);
  }

  const maxedTotal = Math.round(Object.values(maxedCounts).reduce((sum, value) => sum + value, 0));
  const costTotal = Object.values(costsUSD).reduce((sum, value) => sum + value, 0);
  const weekId = isoWeekId(new Date());
  const cf = (request as unknown as { cf?: { country?: string } }).cf;
  const country = sanitizeCountryCode(cf?.country);

  await env.DB.prepare(
    `INSERT INTO entries (week_id, handle, maxed_total, maxed_breakdown, cost_usd_total, cost_breakdown, country, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (week_id, handle) DO UPDATE SET
       maxed_total = excluded.maxed_total,
       maxed_breakdown = excluded.maxed_breakdown,
       cost_usd_total = excluded.cost_usd_total,
       cost_breakdown = excluded.cost_breakdown,
       country = excluded.country,
       updated_at = excluded.updated_at`
  )
    .bind(
      weekId,
      handle,
      maxedTotal,
      JSON.stringify(maxedCounts),
      costTotal,
      JSON.stringify(costsUSD),
      country,
      new Date().toISOString()
    )
    .run();

  return jsonResponse({ weekId, maxedTotal, costTotal, country });
}

async function handleLeaderboard(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const weekId = url.searchParams.get("weekId") ?? isoWeekId(new Date());
  const limitParam = Number(url.searchParams.get("limit") ?? String(DEFAULT_LEADERBOARD_LIMIT));
  const limit = Number.isFinite(limitParam)
    ? Math.min(Math.max(Math.trunc(limitParam), 1), MAX_LEADERBOARD_LIMIT)
    : DEFAULT_LEADERBOARD_LIMIT;

  const maxed = await env.DB.prepare(
    "SELECT handle, maxed_total, maxed_breakdown, country FROM entries WHERE week_id = ? ORDER BY maxed_total DESC LIMIT ?"
  )
    .bind(weekId, limit)
    .all<{ handle: string; maxed_total: number; maxed_breakdown: string; country: string | null }>();

  const reverseVc = await env.DB.prepare(
    "SELECT handle, cost_usd_total, cost_breakdown, country FROM entries WHERE week_id = ? ORDER BY cost_usd_total DESC LIMIT ?"
  )
    .bind(weekId, limit)
    .all<{ handle: string; cost_usd_total: number; cost_breakdown: string; country: string | null }>();

  return jsonResponse({
    weekId,
    maxPlan: (maxed.results ?? []).map((row) => ({
      handle: row.handle,
      total: row.maxed_total,
      breakdown: safeParseObject(row.maxed_breakdown),
      country: row.country,
    })),
    reverseVcFunding: (reverseVc.results ?? []).map((row) => ({
      handle: row.handle,
      totalUsd: row.cost_usd_total,
      breakdown: safeParseObject(row.cost_breakdown),
      country: row.country,
    })),
  });
}

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    try {
      if (request.method === "POST" && url.pathname === "/submit") {
        return await handleSubmit(request, env);
      }
      if (request.method === "GET" && url.pathname === "/leaderboard") {
        return await handleLeaderboard(request, env);
      }
      return jsonResponse({ error: "Not found" }, 404);
    } catch (error) {
      console.error("Unhandled error", error);
      return jsonResponse({ error: "Internal error" }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
