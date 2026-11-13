import { test } from "node:test";
import assert from "node:assert/strict";
import { isRejectedText } from "../src/lib/contentFilter.js";

test("rejects English profanity, slurs and explicit terms as whole words", () => {
  for (const text of [
    "fuck this",
    "What the FUCK.",
    "you are a bitch",
    "this is bullshit!",
    "shit happens",
    "go watch porn",
    "just kill yourself",
    "kill   yourself",
  ]) {
    assert.equal(isRejectedText(text), true, text);
  }
});

test("sees through lookalike digits, symbols, full-width letters and zero-width joins", () => {
  for (const text of ["sh1t", "a$$hole", "b1tch", "ｆｕｃｋ", "fu\u200Bck", "sh\u00ADit"]) {
    assert.equal(isRejectedText(text), true, JSON.stringify(text));
  }
});

test("rejects Thai profanity anywhere in an unspaced sentence", () => {
  for (const text of ["ไอ้สัตว์", "เหี้ยมาก", "พวกมึงมันเหี้ย", "ควยไรเนี่ย", "อีดอกทอง", "สัสจริงๆ"]) {
    assert.equal(isRejectedText(text), true, text);
  }
});

test("lets kind English through, including words that contain a listed term", () => {
  for (const text of [
    "Sending peace to everyone tonight.",
    "Greetings from Scunthorpe",
    "Grandma's shitake soup and a cocktail",
    "Class assessment done, time to breathe",
    "Dick Van Dyke made me smile",
    "My therapist says pause more",
    "Peace to the 1000 people here at 7:45 with $5 and @home",
    "Kill the noise, find yourself",
    "Hope 2026 is gentle",
  ]) {
    assert.equal(isRejectedText(text), false, text);
  }
});

test("lets kind Thai through, including words that contain a fenced term", () => {
  for (const text of [
    "ขอให้โลกสงบสุข",
    "ส่งความรักให้ทุกคน",
    "แกงกะหรี่อร่อยมาก", // curry
    "หีบเพลงของคุณยาย", // accordion
    "กินจนเหี้ยนเลย", // all gone
    "สัสดีอำเภอใจดี", // district registrar
    "ควายตัวใหญ่ในทุ่งนา", // buffalo
    "หายใจเข้าลึกๆ",
  ]) {
    assert.equal(isRejectedText(text), false, text);
  }
});
