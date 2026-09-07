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

function escapeHtml(raw: string): string {
  return raw
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function flagEmoji(countryCode: string | null): string {
  if (!countryCode || !/^[A-Z]{2}$/.test(countryCode)) return "🏳️";
  return String.fromCodePoint(...[...countryCode].map((c) => 0x1f1e6 + c.charCodeAt(0) - 65));
}

function usdText(usd: number): string {
  return "$" + usd.toLocaleString("en-US", { maximumFractionDigits: usd >= 100 ? 0 : 2 });
}

type MaxedRow = { handle: string; maxed_total: number; maxed_breakdown: string; country: string | null };
type CostRow = { handle: string; cost_usd_total: number; cost_breakdown: string; country: string | null };

function breakdownText(json: string, unit: string, money: boolean): string {
  const obj = safeParseObject(json) as Record<string, number>;
  return Object.entries(obj)
    .map(([agent, value]) => `${escapeHtml(agent)} ${money ? usdText(value) : `${Math.round(value)}${unit}`}`)
    .join(" · ");
}

async function handleDashboard(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const weekId = url.searchParams.get("weekId") ?? isoWeekId(new Date());

  const maxed = await env.DB.prepare(
    "SELECT handle, maxed_total, maxed_breakdown, country FROM entries WHERE week_id = ? ORDER BY maxed_total DESC, handle ASC LIMIT ?"
  )
    .bind(weekId, MAX_LEADERBOARD_LIMIT)
    .all<MaxedRow>();

  const reverseVc = await env.DB.prepare(
    "SELECT handle, cost_usd_total, cost_breakdown, country FROM entries WHERE week_id = ? ORDER BY cost_usd_total DESC, handle ASC LIMIT ?"
  )
    .bind(weekId, MAX_LEADERBOARD_LIMIT)
    .all<CostRow>();

  const participants = await env.DB.prepare(
    "SELECT COUNT(DISTINCT handle) as count FROM entries WHERE week_id = ?"
  )
    .bind(weekId)
    .first<{ count: number }>();

  const maxedRows = (maxed.results ?? [])
    .map((row, i) => {
      const detail = breakdownText(row.maxed_breakdown, "", false);
      return `<tr><td class="rank">${i + 1}</td><td>${flagEmoji(row.country)} ${escapeHtml(row.handle)}</td>` +
        `<td class="num">${Math.round(row.maxed_total)} maxed</td>` +
        (detail ? `<td class="detail">${detail}</td>` : "<td class=\"detail\"></td>") + "</tr>";
    })
    .join("\n");

  const costRows = (reverseVc.results ?? [])
    .map((row, i) => {
      const detail = breakdownText(row.cost_breakdown, "", true);
      return `<tr><td class="rank">${i + 1}</td><td>${flagEmoji(row.country)} ${escapeHtml(row.handle)}</td>` +
        `<td class="num">${usdText(row.cost_usd_total)}</td>` +
        (detail ? `<td class="detail">${detail}</td>` : "<td class=\"detail\"></td>") + "</tr>";
    })
    .join("\n");

  const section = (emoji: string, title: string, subtitle: string, rows: string): string => `
    <section class="card">
      <h2>${emoji} ${title}</h2>
      <p class="subtitle">${subtitle}</p>
      ${rows
        ? `<table><tbody>${rows}</tbody></table>`
        : '<p class="empty">No entries yet this week.</p>'}
    </section>`;

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>vc-funding — Weekly leaderboard</title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='0.9em' font-size='90'>🤑</text></svg>">
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 32px 20px 48px;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
    background: #0d1117; color: #e6edf3;
  }
  .wrap { max-width: 780px; margin: 0 auto; }
  header { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; margin-bottom: 24px; }
  header h1 { font-size: 24px; margin: 0; }
  header .week { color: #8b949e; font-size: 14px; }
  header .count { margin-left: auto; color: #8b949e; font-size: 13px; }
  .card {
    background: #161b22; border: 1px solid #30363d; border-radius: 12px;
    padding: 20px 22px; margin-bottom: 20px;
  }
  .card h2 { margin: 0 0 2px; font-size: 17px; }
  .subtitle { margin: 0 0 14px; color: #8b949e; font-size: 13px; }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  td { padding: 8px 6px; border-top: 1px solid #21262d; vertical-align: baseline; }
  tr:first-child td { border-top: none; }
  .rank { width: 30px; color: #8b949e; font-variant-numeric: tabular-nums; }
  .num { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; font-weight: 600; }
  .detail { color: #8b949e; font-size: 12px; text-align: right; }
  .empty { color: #8b949e; }
  footer { color: #6e7681; font-size: 12px; margin-top: 8px; line-height: 1.5; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>🤑 vc-funding</h1>
    <span class="week">Week ${escapeHtml(weekId)}</span>
    <span class="count">${participants?.count ?? 0} participant${(participants?.count ?? 0) === 1 ? "" : "s"} this week</span>
  </header>
  ${section("🏆", "Maxeur de plan max", "Most 5-hour windows maxed out this week", maxedRows)}
  ${section("💸", "Reverse VC funding", "Most spent out of pocket this week", costRows)}
  <footer>
    No login — anyone can post any handle/number, so treat scores as for fun, not verified.<br>
    Share yours from the vc-funding macOS menu-bar app.
  </footer>
</div>
</body>
</html>`;

  return new Response(html, {
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=30" },
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
      if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/dashboard")) {
        return await handleDashboard(request, env);
      }
      return jsonResponse({ error: "Not found" }, 404);
    } catch (error) {
      console.error("Unhandled error", error);
      return jsonResponse({ error: "Internal error" }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
