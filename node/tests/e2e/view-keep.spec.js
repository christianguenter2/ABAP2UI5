// @ts-check
// A view_display( ) with the XML the browser already shows keeps the live
// view (core/actions/Slots canKeep): no control is destroyed or created,
// and the data arrives through the model push the display carries. A
// view_destroy( ) before the display in the same roundtrip builds it anew.
//
// The fixture app is node/srv/zcl_tst_bench_view.clas.abap, copied into the
// transpiled backend by `npm run auto_transpile`: a form and a table of 50
// rows, a counter every event raises, and the three events REDISPLAY (the
// same XML again), REBUILD (destroy, then display) and DATA (no display).
// It doubles as the bench fixture behind the numbers in actions/Slots.
const { test, expect } = require("./fixtures");

// the live counter control, the instance the checks compare
async function counterControl(page) {
  return page.evaluateHandle(() => {
    const Element = sap.ui.require("sap/ui/core/Element");
    const dom = document.querySelector("[id$='txtCounter']");
    return Element.getElementById(dom.id);
  });
}

async function press(page, button, expectCounter) {
  await page.evaluate((suffix) => {
    const Element = sap.ui.require("sap/ui/core/Element");
    const dom = document.querySelector(`[id$='${suffix}']`);
    Element.getElementById(dom.id).firePress();
  }, button);
  await expect(page.locator("[id$='txtCounter']")).toHaveText(
    String(expectCounter),
  );
}

test("the same XML again keeps the view, a destroy before it rebuilds", async ({
  page,
}) => {
  await page.goto("/?app_start=zcl_tst_bench_view");
  await expect(page.locator("[id$='txtCounter']")).toHaveText("0", {
    timeout: 30000,
  });
  const first = await counterControl(page);

  await press(page, "btnRedisplay", 1);
  const afterRedisplay = await counterControl(page);
  expect(await page.evaluate(([a, b]) => a === b, [first, afterRedisplay])).toBe(
    true,
  );
  expect(await first.evaluate((c) => c.isDestroyed?.() ?? c.bIsDestroyed)).toBe(
    false,
  );

  await press(page, "btnData", 2);

  await press(page, "btnRebuild", 3);
  const afterRebuild = await counterControl(page);
  expect(await page.evaluate(([a, b]) => a === b, [first, afterRebuild])).toBe(
    false,
  );

  // the rebuilt view is kept from here on like the first one was
  await press(page, "btnRedisplay", 4);
  const afterSecond = await counterControl(page);
  expect(
    await page.evaluate(([a, b]) => a === b, [afterRebuild, afterSecond]),
  ).toBe(true);
});
