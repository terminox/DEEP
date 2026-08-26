// ISO-3166-1 alpha-2 → continent, for the Global Pause "where the world is
// pausing" readout. Complete on purpose: the app's own country table covers
// only the ~67 nations whose globe glow was hand-tuned, so classifying
// client-side would quietly drop everyone else from the count.
//
// Continent codes match MaxMind's (`rec.continent.code`), so an IP-resolved
// continent and one derived from a country code always speak the same alphabet.

/** The seven continent codes. Antarctica is real, rare, and welcome. */
export type ContinentISO = "AF" | "AN" | "AS" | "EU" | "NA" | "OC" | "SA";

// Grouped by continent rather than keyed by country: one line per continent is
// scannable, and adding a territory is a one-word edit. Inverted once at module
// load. Note "AS" appears in the Oceania line — American Samoa, not Asia; the
// keys are continents, the values are countries.
const COUNTRIES_BY_CONTINENT: Record<ContinentISO, string> = {
  AF: "AO BF BI BJ BW CD CF CG CI CM CV DJ DZ EG EH ER ET GA GH GM GN GQ GW KE KM LR LS LY MA MG ML MR MU MW MZ NA NE NG RE RW SC SD SH SL SN SO SS ST SZ TD TG TN TZ UG YT ZA ZM ZW",
  AN: "AQ BV GS HM TF",
  AS: "AE AF AM AZ BD BH BN BT CC CN CX CY GE HK ID IL IN IO IQ IR JO JP KG KH KP KR KW KZ LA LB LK MM MN MO MV MY NP OM PH PK PS QA SA SG SY TH TJ TL TM TR TW UZ VN YE",
  EU: "AD AL AT AX BA BE BG BY CH CZ DE DK EE ES FI FO FR GB GG GI GR HR HU IE IM IS IT JE LI LT LU LV MC MD ME MK MT NL NO PL PT RO RS RU SE SI SJ SK SM UA VA",
  NA: "AG AI AW BB BL BM BQ BS BZ CA CR CU CW DM DO GD GL GP GT HN HT JM KN KY LC MF MQ MS MX NI PA PM PR SV SX TC TT US VC VG VI",
  OC: "AS AU CK FJ FM GU KI MH MP NC NF NR NU NZ PF PG PN PW SB TK TO TV UM VU WF WS",
  SA: "AR BO BR CL CO EC FK GF GY PE PY SR UY VE",
};

const CONTINENT_BY_COUNTRY = new Map<string, ContinentISO>();
for (const [continent, countries] of Object.entries(COUNTRIES_BY_CONTINENT)) {
  for (const iso of countries.split(" ")) {
    CONTINENT_BY_COUNTRY.set(iso, continent as ContinentISO);
  }
}

/** True for one of the seven continent codes. */
export function isContinentISO(value: string | null | undefined): value is ContinentISO {
  return value != null && Object.prototype.hasOwnProperty.call(COUNTRIES_BY_CONTINENT, value);
}

/** The continent a country sits on, or null for an unknown or missing code. */
export function continentForCountry(iso: string | null | undefined): ContinentISO | null {
  if (!iso) return null;
  return CONTINENT_BY_COUNTRY.get(iso.toUpperCase()) ?? null;
}
