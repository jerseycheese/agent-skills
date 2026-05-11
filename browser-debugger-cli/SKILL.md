---
name: browser-debugger-cli
description: >
  Inspect and debug live web pages using the Chrome DevTools Protocol via the `bdg` CLI.
  Use for targeted DOM queries, computed style checks, layout debugging, and CDP method calls
  without loading a full page snapshot. Prefer over chrome-devtools-mcp for token efficiency.
  Trigger on: "inspect element", "check computed styles", "query the DOM", "what does the DOM look like",
  "debug layout", "check the CSS on", "run a DevTools query", "what's the rendered style of", "inspect the page".
---

# browser-debugger-cli (bdg)

## When to use
- Query specific DOM elements or attributes
- Run targeted CDP methods without full page snapshots
- Debug with minimal token overhead

## Prerequisites
- Install: `npm install -g browser-debugger-cli@alpha`
- Chrome available locally, or connect via `--chrome-ws-url`

## Common workflow
1. Start a session:
   - `bdg http://localhost:3000`
2. Query DOM:
   - `bdg dom query "button"`
   - `bdg dom query "[data-testid='x']"`
3. Discover CDP methods:
   - `bdg cdp --list`
   - `bdg cdp --search dom`
4. Evaluate JS:
   - `bdg cdp Runtime.evaluate --params '{"expression":"document.title"}'`
5. Stop the session:
   - `bdg stop`

## Notes
- Use `bdg status` or `bdg peek` to inspect without stopping.
- Use `bdg --no-headless` when you need a visible browser window.
- **AeroSpace tiling**: When using `--no-headless`, AeroSpace will tile the browser window, constraining its viewport to whatever space the tiling layout assigns. Run `aerospace layout floating` after the window appears to free it from tiling constraints. Without this, viewport-dependent CSS (media queries, responsive layouts) may not match expected breakpoints.
- For full page snapshots or complex automation, use Chrome DevTools MCP.
