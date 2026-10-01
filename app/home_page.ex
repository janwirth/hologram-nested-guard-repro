defmodule HologramSkeleton.HomePage do
  @moduledoc """
  Reproduction: a guard with a long `in` list makes the client bundle
  unparseable in Firefox ("InternalError: too much recursion" /
  "function nested too deeply"), so no action on the page runs.

  `x in [a, b, c, ...]` expands to `x === a or x === b or x === c ...`, a
  left-nested chain of `:erlang.orelse` calls. The encoder emits one nested
  closure per operand, and one nested blame object per operand for the
  function clause heads, so `known_zone?/1` below becomes a 600-deep
  expression in the page bundle. Chrome parses it only because its default
  JS stack is large enough; `--js-flags=--stack-size=300` makes it fail too.
  """
  use Hologram.Page

  route "/"

  layout HologramSkeleton.DefaultLayout

  # 600 names, like the IANA time-zone list in ex_cldr's
  # Cldr.Validity.U.encode_key/2 where this was first hit.
  @zones for i <- 1..600, do: "Zone/#{i}"

  def init(_params, component, _server) do
    put_state(component, count: 0, result: nil)
  end

  def action(:increment, _params, component) do
    put_state(component, :count, component.state.count + 1)
  end

  def action(:check, _params, component) do
    put_state(component, :result, known_zone?("Zone/42"))
  end

  # Reachable from the client through the :check action, so the compiler
  # ships it in the page bundle - with a 600-way guard.
  def known_zone?(zone) when zone in @zones, do: true
  def known_zone?(_zone), do: false

  def template do
    ~HOLO"""
    <main style="font-family: sans-serif; max-width: 40rem; margin: 4rem auto; line-height: 1.5;">
      <h1>Hologram: 600-way <code>in</code> guard</h1>
      <p>
        If this page works, the number below changes on click and “Check zone” prints
        <code>true</code>. In Firefox the page bundle does not even parse
        (<code>InternalError: too much recursion</code> in the console), so nothing reacts.
      </p>
      <p id="count" style="font-size: 3rem; margin: 1rem 0;">{@count}</p>
      <p>
        <button type="button" $click="increment">+1</button>
        <button type="button" $click="check">Check zone</button>
      </p>
      {%if @result != nil}
        <p>known_zone?("Zone/42") = <code>{@result}</code></p>
      {/if}
      <p style="color: #666; font-size: 0.9rem;">
        Source: <a href="https://github.com/janwirth/hologram-nested-guard-repro">janwirth/hologram-nested-guard-repro</a>
        · the guard is <code>when zone in @zones</code> with 600 entries in <code>app/home_page.ex</code>.
      </p>
    </main>
    """
  end
end
