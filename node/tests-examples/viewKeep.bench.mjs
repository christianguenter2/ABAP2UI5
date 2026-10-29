#!/usr/bin/env node
/*
 * viewKeep.bench.mjs - what a view_display( ) of an UNCHANGED view costs,
 * against a rebuild and against a roundtrip that displays nothing.
 *
 * Reference material, not a gate: the numbers are the machine's. The
 * frontend keeps a slot that already shows the XML a display carries
 * (app/webapp/core/actions/Slots.js, canKeep); before that, every same-XML
 * redisplay destroyed and rebuilt the whole view. The fixture app is
 * node/srv/zcl_tst_bench_view.clas.abap - a form of eight inputs and a
 * table of 50 rows - with three buttons that raise the same counter:
 *   REBUILD    view_destroy( ) + view_display( ): built anew, what every
 *              redisplay cost before
 *   REDISPLAY  view_display( ) with the same XML: kept
 *   DATA       no display at all: the model push alone
 * Each event runs `rounds` times after five warm-ups; the medians are
 * printed - total (press to the new counter on screen, one frame later),
 * server (request start to response end) and frontend (response end to
 * on screen), plus the mean response size.
 *
 *   npm run express                                       in one shell
 *   node node/tests-examples/viewKeep.bench.mjs [rounds]  in another
 *
 *   BENCH_CPU=4         Chromium's CPU throttling (a slower client)
 *   BENCH_CHROMIUM      path to a Chromium executable (optional)
 *   BENCH_UI5           the sap-ui-core.js the page boots (default: the
 *                       pinned build of node/playwright.config.js)
 *
 * Measured 2026-10-29 (median of 40, Chromium headless, UI5 1.144.0):
 *              REBUILD   REDISPLAY   DATA
 *   CPU x1     75 ms     32 ms       32 ms
 *   CPU x4    270 ms     48 ms       48 ms
 */
/* global document, requestAnimationFrame, sap -- page.evaluate( ) runs in the browser */
import { chromium } from "playwright";

const ROUNDS = Number(process.argv[2] || 30);
const UI5 =
  process.env.BENCH_UI5 ||
  "https://sdk.openui5.org/1.144.0/resources/sap-ui-core.js";
const BASE = "http://localhost:3000";

const browser = await chromium.launch({
  executablePath: process.env.BENCH_CHROMIUM || undefined,
});
const page = await browser.newPage();
if (process.env.BENCH_CPU) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Emulation.setCPUThrottlingRate", {
    rate: Number(process.env.BENCH_CPU),
  });
}
// the page names the evergreen CDN build - pinned here like the e2e fixture
await page.route("**/*", async (route) => {
  const req = route.request();
  if (req.resourceType() !== "document" || !req.url().startsWith(BASE)) {
    return route.continue();
  }
  const resp = await route.fetch();
  const body = (await resp.text()).replace(
    /https:\/\/[^"']*sap-ui-core\.js/g,
    UI5,
  );
  return route.fulfill({ response: resp, body });
});
const sizes = [];
page.on("response", async (r) => {
  if (r.request().method() !== "POST") return;
  try {
    sizes.push((await r.body()).length);
  } catch {
    // a response the page discarded
  }
});

await page.goto(`${BASE}/?app_start=zcl_tst_bench_view`);
await page.waitForFunction(
  () => !!document.querySelector("[id$='txtCounter']"),
  null,
  { timeout: 60000 },
);

function press(button) {
  return page.evaluate(async (suffix) => {
    const Element = sap.ui.require("sap/ui/core/Element");
    const counter = () => document.querySelector("[id$='txtCounter']");
    const before = Number(counter().textContent);
    performance.clearResourceTimings();
    const t0 = performance.now();
    Element.getElementById(
      document.querySelector(`[id$='${suffix}']`).id,
    ).firePress();
    await new Promise((resolve) => {
      const tick = () => {
        if (Number(counter()?.textContent) === before + 1) resolve();
        else requestAnimationFrame(tick);
      };
      tick();
    });
    await new Promise((r) => requestAnimationFrame(() => setTimeout(r, 0)));
    const t1 = performance.now();
    const res = performance
      .getEntriesByType("resource")
      .filter((e) => ["fetch", "xmlhttprequest"].includes(e.initiatorType))
      .pop();
    return {
      total: t1 - t0,
      server: res ? res.responseEnd - res.requestStart : NaN,
      frontend: res ? t1 - res.responseEnd : NaN,
    };
  }, button);
}

const median = (rows, key) => {
  const v = rows.map((r) => r[key]).sort((a, b) => a - b);
  return v[Math.floor(v.length / 2)].toFixed(1);
};

for (const [label, button] of [
  ["REBUILD", "btnRebuild"],
  ["REDISPLAY", "btnRedisplay"],
  ["DATA", "btnData"],
]) {
  for (let i = 0; i < 5; i++) await press(button);
  sizes.length = 0;
  const rows = [];
  for (let i = 0; i < ROUNDS; i++) rows.push(await press(button));
  const bytes = Math.round(sizes.reduce((a, b) => a + b, 0) / sizes.length);
  console.log(
    `${label.padEnd(10)} total ${median(rows, "total")} ms` +
      `  server ${median(rows, "server")} ms` +
      `  frontend ${median(rows, "frontend")} ms  ${bytes} B`,
  );
}
await browser.close();
