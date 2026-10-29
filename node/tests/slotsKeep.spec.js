// @ts-check
const { test, expect } = require("@playwright/test");
const { loadModule } = require("./loadModule");
const { specContext, contextStub, bindContext } = require("./loadLibModule");

// core/actions/Slots.js - keeping a slot whose view is unchanged. A display
// of the XML a slot already holds, with the same options and for the same
// app, keeps the live view instead of rebuilding it; the model push of the
// response brings the data (View1, MODELPRESENT - not under test here).
// The backend asks for a real rebuild with `rebuild`.
//
// ViewSlots is a small stateful stand-in here: what a display records
// (setView) is what the next display compares against.
function load() {
  const builds = [];
  const destroyed = [];
  let created = 0;

  class JSONModel {
    constructor(data) {
      this.data = data;
    }
    attachPropertyChange() {}
    setSizeLimit() {}
    setData(data) {
      this.data = data;
    }
    destroy() {}
  }

  function newControl(kind) {
    created += 1;
    const control = {
      kind,
      n: created,
      destroyed: false,
      shown: false,
      setModel() {},
      getModel() {},
      getId: () => `${kind}${control.n}`,
      // rendered, so a MAIN display is no first display (transitionPlan)
      getDomRef: () => ({}),
      destroy() {
        control.destroyed = true;
      },
      isOpen: () => control.shown,
      open() {
        control.shown = true;
      },
      openBy() {
        control.shown = true;
      },
    };
    return control;
  }

  const oApp = {
    pages: [],
    getDomRef: () => ({}),
    removeAllPages() {
      oApp.pages = [];
    },
    insertPage(page) {
      oApp.pages.push(page);
    },
    removePage() {},
  };
  const anchor = { id: "anchor", getId: () => "anchor" };
  const parent = { insertContent() {}, destroyContent() {} };

  const ctx = specContext({
    oApp,
    oResponse: { APP: "ZCL_APP", OVIEWMODEL: { A: 1 } },
  });
  ctx.server.requestSeq = 1;
  const state = ctx.state;
  const live = {};
  const xmlOf = {};
  const optionsOf = {};
  const appOf = {};

  function drop(key) {
    delete live[key];
    delete xmlOf[key];
    delete optionsOf[key];
    delete appOf[key];
  }

  const { module } = loadModule("core/actions/Slots.js", {
    deps: {
      "sap/ui/core/mvc/XMLView": {
        create: (o) => {
          builds.push(o.definition);
          return Promise.resolve(newControl("view"));
        },
      },
      "sap/ui/core/Fragment": {
        load: (o) => {
          builds.push(o.definition);
          return Promise.resolve(newControl("fragment"));
        },
      },
      "sap/ui/model/json/JSONModel": JSONModel,
      "sap/ui/model/odata/v2/ODataModel": class {},
      "z2ui5/core/Context": contextStub(ctx),
      "z2ui5/core/Lib": {
        logError: () => {},
        usesXmlTemplating: () => false,
        isAlive: (o) => Boolean(o) && !o.destroyed,
        isRootModelSlot: (key) => ["MAIN", "NEST", "NEST2"].includes(key),
        effectiveSizeLimit: () => undefined,
        whenRendered: (control, _owner, fn) => fn(control),
        requireODataModel: async () =>
          class {
            destroy() {}
          },
      },
      "z2ui5/core/Env": {
        preloadFragmentModules: async () => {},
        loadViewLibraries: async () => {},
      },
      "z2ui5/core/ViewSlots": {
        ownId: (_ctx, id) => id,
        fragmentIdOf: (_ctx, slot) => slot.fragmentId,
        slots: [
          { key: "MAIN", ownsModel: true },
          { key: "POPUP", ownsModel: true },
          { key: "POPOVER", ownsModel: true },
        ],
        destroy: (_ctx, key) => {
          if (live[key]) live[key].destroyed = true;
          if (live[key]) destroyed.push(key);
          drop(key);
        },
        detach: (_ctx, key) => {
          const view = live[key];
          drop(key);
          return view;
        },
        setView: (_ctx, key, view, xml, options) => {
          live[key] = view;
          xmlOf[key] = xml;
          optionsOf[key] = options ?? {};
          appOf[key] = state.oResponse?.APP;
        },
        getController: () => null,
        getView: (_ctx, key) => live[key],
        getViewApp: (_ctx, key) => appOf[key],
        getViewXml: (_ctx, key) => xmlOf[key],
        getViewOptions: (_ctx, key) => optionsOf[key],
        trackedModel: () => undefined,
        resolveById: () => anchor,
        byId: () => parent,
      },
    },
  });
  const Slots = bindContext(module, ctx, ["action"]);

  // a response: the app that answers and its system actions, as View1
  // hands them over (ctx.state.oResponse)
  function respond(app, displays = []) {
    state.oResponse = {
      APP: app,
      OVIEWMODEL: { A: 1 },
      S_ACTION: {
        T_SYSTEM: displays.map((key) => ["VIEW_SLOTS", "display", key]),
      },
    };
  }

  return { Slots, state, live, builds, destroyed, respond };
}

test("the same MAIN XML again keeps the live view", async () => {
  const { Slots, live, builds, respond } = load();
  respond("ZCL_APP", ["MAIN"]);
  await Slots.action("display", "MAIN", "<View/>");
  const first = live.MAIN;

  respond("ZCL_APP", ["MAIN"]);
  await Slots.action("display", "MAIN", "<View/>");

  expect(builds).toEqual(["<View/>"]);
  expect(live.MAIN).toBe(first);
  expect(first.destroyed).toBe(false);
});

test("other XML, other options, another app or a rebuild request build anew", async () => {
  const { Slots, live, builds, respond } = load();
  respond("ZCL_APP", ["MAIN"]);
  await Slots.action("display", "MAIN", "<View/>");

  await Slots.action("display", "MAIN", "<View a='1'/>");
  await Slots.action("display", "MAIN", "<View a='1'/>", {
    switchDefaultModelPath: "/odata/",
  });
  respond("ZCL_OTHER", ["MAIN"]);
  await Slots.action("display", "MAIN", "<View a='1'/>", {
    switchDefaultModelPath: "/odata/",
  });
  await Slots.action("display", "MAIN", "<View a='1'/>", {
    switchDefaultModelPath: "/odata/",
    rebuild: true,
  });

  expect(builds.length).toBe(5);
  expect(live.MAIN.destroyed).toBe(false);
});

test("a kept MAIN ends the popup the response does not display again", async () => {
  const { Slots, live, builds, destroyed, respond } = load();
  respond("ZCL_APP", ["MAIN", "POPUP"]);
  await Slots.action("display", "MAIN", "<View/>");
  await Slots.action("display", "POPUP", "<Dialog/>");
  const popup = live.POPUP;
  expect(popup.shown).toBe(true);

  // MAIN and the popup again, unchanged: both stay
  respond("ZCL_APP", ["MAIN", "POPUP"]);
  await Slots.action("display", "MAIN", "<View/>");
  await Slots.action("display", "POPUP", "<Dialog/>");
  expect(live.POPUP).toBe(popup);
  expect(builds.length).toBe(2);

  // MAIN alone: the popup goes, as it does with a rebuilt MAIN - the
  // backend sends no destroy for it next to a MAIN display
  respond("ZCL_APP", ["MAIN"]);
  await Slots.action("display", "MAIN", "<View/>");
  expect(destroyed).toEqual(["POPUP"]);
  expect(live.POPUP).toBe(undefined);
  expect(builds.length).toBe(2);
});

test("a popup the user closed meanwhile is opened anew", async () => {
  const { Slots, live, builds, respond } = load();
  respond("ZCL_APP", ["POPUP"]);
  await Slots.action("display", "POPUP", "<Dialog/>");
  live.POPUP.shown = false;

  await Slots.action("display", "POPUP", "<Dialog/>");

  expect(builds.length).toBe(2);
  expect(live.POPUP.shown).toBe(true);
});

test("a popover keeps only for the same anchor", async () => {
  const { Slots, live, builds, respond } = load();
  respond("ZCL_APP", ["POPOVER"]);
  await Slots.action("display", "POPOVER", "<Popover/>", { openById: "a" });
  const popover = live.POPOVER;

  await Slots.action("display", "POPOVER", "<Popover/>", { openById: "a" });
  expect(live.POPOVER).toBe(popover);

  await Slots.action("display", "POPOVER", "<Popover/>", { openById: "b" });
  expect(builds.length).toBe(2);
});

test("a nested view keeps across a response that leaves MAIN alone", async () => {
  const { Slots, live, builds, respond } = load();
  respond("ZCL_APP", ["MAIN", "NEST"]);
  const nest = { id: "box", methodInsert: "insertContent" };
  await Slots.action("display", "MAIN", "<View/>");
  await Slots.action("display", "NEST", "<View n='1'/>", nest);
  const nested = live.NEST;

  respond("ZCL_APP", ["NEST"]);
  await Slots.action("display", "NEST", "<View n='1'/>", nest);
  expect(live.NEST).toBe(nested);

  // a kept MAIN without the nested view in the response ends it, as the
  // rebuilt page did
  respond("ZCL_APP", ["MAIN"]);
  await Slots.action("display", "MAIN", "<View/>");
  expect(live.NEST).toBe(undefined);
  expect(builds.length).toBe(2);
});

test("a MAIN display with a page transition never keeps", async () => {
  const { Slots, builds, respond } = load();
  respond("ZCL_APP", ["MAIN"]);
  await Slots.action("display", "MAIN", "<View/>");
  // the NavContainer part of a transition is mainTransition.spec.js's
  // subject - only that it is not skipped matters here
  const build = Slots.action("display", "MAIN", "<View/>", {
    transition: "slide",
  });
  await Promise.race([
    build.catch(() => {}),
    new Promise((r) => setTimeout(r, 50)),
  ]);
  expect(builds.length).toBe(2);
});
