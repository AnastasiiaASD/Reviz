# Browser Automation with playwright-cli

## ⛔ Token budget — read first

Every `playwright-cli snapshot` dumped to stdout costs 5–15k tokens because the full accessibility tree is fed back into your context. Follow these rules or you will burn the 5-hour quota window in a single ticket:

- **Never run bare `playwright-cli snapshot`.** Always write to a file and grep it:
  ```bash
  playwright-cli snapshot --filename=/tmp/snap.yml
  grep -A3 'heading' /tmp/snap.yml | head -40
  ```
- **Max 2 snapshots per session.** If you need more, you are exploring instead of testing — re-read the Page Objects in `tests/pages/` and reuse what's there.
- **Prefer `playwright-cli eval` on a known ref over a fresh snapshot.** Example: `playwright-cli eval "el => el.outerHTML" e15` returns just one element.
- **Do not call `console`, `network`, `tracing`, or `video`.** They are not needed for writing tests and they push more bytes back into context.

## Commands you may use

```bash
# Open and navigate
playwright-cli open                          # create session
playwright-cli open https://example.com/     # open and navigate at once
playwright-cli goto https://example.com/page
playwright-cli close                         # always close when done

# Inspect (respect the budget rule above)
playwright-cli snapshot --filename=/tmp/snap.yml
playwright-cli eval "document.title"
playwright-cli eval "el => el.outerHTML" e15

# Interact (use refs from a snapshot file)
playwright-cli click e3
playwright-cli fill e5 "user@example.com"
playwright-cli select e9 "option-value"
playwright-cli check e12
playwright-cli uncheck e12
playwright-cli hover e4
playwright-cli press Enter
playwright-cli press ArrowDown

# Navigation
playwright-cli go-back
playwright-cli reload
```

## Example flow

```bash
playwright-cli open https://[REVYOOS_DEMO_URL]/sign-in
playwright-cli snapshot --filename=/tmp/snap.yml
grep -A2 'email' /tmp/snap.yml | head
# Use the ref you just found:
playwright-cli fill e7 "admin@revyoos.com"
playwright-cli fill e8 "password"
playwright-cli click e9
playwright-cli close
```

## When NOT to use playwright-cli at all

If the selector you need is already defined in `/app/repo/tests/pages/`, do not open a browser. Read the Page Object file, reuse the selector, write the test. Browser exploration is for widgets/flows that have no existing coverage.
