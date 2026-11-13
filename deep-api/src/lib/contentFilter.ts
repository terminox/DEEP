// The pre-publish word filter for peace messages (Apple Guideline 1.2). Peace
// messages go public on post, so this catches the obvious; reports and admin
// moderation catch the rest. It is deliberately short and high-precision: a
// kind message refused for an innocent word is worse than a rude one slipping
// through to the report button.

// English matches whole words only, so "Scunthorpe", "cocktail" or "class"
// never trip it. Forms are listed out rather than stemmed: `shit\w*` would
// refuse "shitake".
const ENGLISH = [
  "fuck", "fucks", "fucked", "fucker", "fuckers", "fucking", "fuckin", "motherfucker",
  "motherfuckers", "shit", "shits", "shitty", "shitting", "bullshit", "bitch", "bitches",
  "cunt", "cunts", "asshole", "assholes", "whore", "whores", "slut", "sluts", "nigger",
  "niggers", "nigga", "niggas", "faggot", "faggots", "retard", "retards", "retarded", "kike",
  "kikes", "tranny", "trannies", "wetback", "wetbacks", "porn", "porno", "blowjob", "blowjobs",
  "dildo", "dildos", "jizz", "kill yourself",
];

// Thai has no spaces between words, so these match anywhere in the text. Each
// is chosen (or fenced with a lookahead) so it never sits inside an innocent
// word: เหี้ย but not เหี้ยน ("all gone"), สัส but not สัสดี (a registrar).
// Left out on purpose: หี (inside หีบ, a chest) and กะหรี่ (also "curry").
const THAI = ["เหี้ย(?!น)", "ควย", "เย็ด", "ไอ้สัตว์", "อีดอก", "ระยำ", "ชาติหมา", "สัส(?!ดี)"];

const englishPattern = new RegExp(
  `(?<![a-z])(?:${ENGLISH.map((w) => w.replace(/ /g, "\\s+")).join("|")})(?![a-z])`,
);
const thaiPattern = new RegExp(THAI.join("|"));

// The usual dodges: full-width letters (NFKC folds them), zero-width
// characters slipped between letters, and digit/symbol stand-ins ("sh1t").
// Not "!": it ends sentences, and "shit!" must still end on a word boundary.
const LOOKALIKES: Record<string, string> = {
  "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s",
};

function normalize(text: string): string {
  return text
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\u2060\uFEFF\u00AD]/g, "")
    .toLowerCase()
    .replace(/[013457@$]/g, (c) => LOOKALIKES[c]!);
}

/** True when the text contains a term DEEP never publishes. */
export function isRejectedText(text: string): boolean {
  const normalized = normalize(text);
  return englishPattern.test(normalized) || thaiPattern.test(normalized);
}
