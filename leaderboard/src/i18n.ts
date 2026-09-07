export type Lang = "en" | "fr";

const SUPPORTED: readonly Lang[] = ["en", "fr"];

/**
 * Resolves the dashboard language from an explicit ?lang= override first,
 * then from the browser's Accept-Language header. Defaults to English.
 */
export function resolveLang(request: Request): Lang {
  const url = new URL(request.url);
  const forced = url.searchParams.get("lang");
  if (forced === "en" || forced === "fr") return forced;

  const header = request.headers.get("accept-language") ?? "";
  for (const part of header.split(",")) {
    const tag = (part.split(";")[0] ?? "").trim().toLowerCase();
    if (tag.startsWith("fr")) return "fr";
    if (tag.startsWith("en")) return "en";
  }
  return "en";
}

export function isLang(value: unknown): value is Lang {
  return typeof value === "string" && (SUPPORTED as readonly string[]).includes(value);
}

export interface Translations {
  readonly htmlLang: string;
  readonly pageTitle: string;
  readonly weekLabel: string;
  readonly participants: (n: number) => string;
  readonly maxTitle: string;
  readonly maxSubtitle: string;
  readonly vcTitle: string;
  readonly vcSubtitle: string;
  readonly maxedUnit: (n: number) => string;
  readonly empty: string;
  readonly footerLine1: string;
  readonly footerLine2: string;
}

const en: Translations = {
  htmlLang: "en",
  pageTitle: "vc-funding — Weekly leaderboard",
  weekLabel: "Week",
  participants: (n: number) => `${n} participant${n === 1 ? "" : "s"} this week`,
  maxTitle: "Maxeur de plan max",
  maxSubtitle: "Most 5-hour windows maxed out this week",
  vcTitle: "Corporate Maxing",
  vcSubtitle: "Most spent out of pocket this week",
  maxedUnit: (n: number) => `${n} maxed`,
  empty: "No entries yet this week.",
  footerLine1: "No login — anyone can post any handle/number, so treat scores as for fun, not verified.",
  footerLine2: "Share yours from the vc-funding macOS menu-bar app.",
};

const fr: Translations = {
  htmlLang: "fr",
  pageTitle: "vc-funding — Classement hebdomadaire",
  weekLabel: "Semaine",
  participants: (n: number) => `${n} participant${n === 1 ? "" : "s"} cette semaine`,
  maxTitle: "Maxeur de plan max",
  maxSubtitle: "Plus de fenêtres de 5 h saturées cette semaine",
  vcTitle: "Corporate Maxing",
  vcSubtitle: "Plus grosse somme dépensée de sa poche cette semaine",
  maxedUnit: (n: number) => `${n} saturée${n === 1 ? "" : "s"}`,
  empty: "Aucune entrée pour l'instant cette semaine.",
  footerLine1:
    "Pas de connexion — n'importe qui peut poster n'importe quel pseudo/chiffre : scores à prendre pour du fun, non vérifiés.",
  footerLine2: "Partage les tiennes depuis l'app macOS vc-funding dans la barre de menus.",
};

export function translations(lang: Lang): Translations {
  return lang === "fr" ? fr : en;
}

/** Per-number formatting locale so currency renders as the visitor expects. */
export function numberLocale(lang: Lang): string {
  return lang === "fr" ? "fr-FR" : "en-US";
}
