# Hologram repro: a 600-way `in` guard breaks the client bundle in Firefox

Minimal reproduction, forked from [hologram_skeleton](https://github.com/bartblast/hologram_skeleton).
Live at https://hologram-nested-guard-repro.jan-wirth.dev.

## The bug

`app/home_page.ex` has one function reachable from a client action:

```elixir
@zones for i <- 1..600, do: "Zone/#{i}"

def known_zone?(zone) when zone in @zones, do: true
def known_zone?(_zone), do: false
```

`x in [a, b, c, ...]` expands to `x === a or x === b or ...`, a left-nested
chain of `:erlang.orelse` calls. Hologram's encoder emits one nested closure
per operand for the guard, and one nested blame object per operand for the
function's clause heads, so the page bundle carries a 600-deep expression.

- **Firefox**: the bundle fails to parse — `InternalError: too much recursion`
  (or `function nested too deeply`) in the console right after
  `Hologram: page script executed`. Nothing on the page reacts to a click.
- **Chrome**: works only because its default JS stack is large; launch it with
  `--js-flags=--stack-size=300` and the bundle fails with
  `RangeError: Maximum call stack size exceeded`.

First hit in a real app through ex_cldr's `Cldr.Validity.U.encode_key/2`, a
function with an `in` guard over the 601 IANA time-zone names. Hologram stubs
that function ("output too big") but still emits its clause heads, so every
app that has `ex_cldr` in its dependency tree gets a runtime bundle Firefox
cannot parse, whether or not the app calls Cldr.

## Run it

```bash
mix setup
HOLOGRAM_START=1 mix phx.server
```

Open http://localhost:4000 in Firefox: the counter does not move. Open the
console: `InternalError: too much recursion`.

## Fix

Proposed in bartblast/hologram as *Flatten left-nested and/or chains in the
encoder*: chains of three or more operands become one
`Interpreter.orelseChain([...])` / `andalsoChain([...])` call, and one blame
node with an `operands` list that the client folds back into the tuples the
error renderer expects.
