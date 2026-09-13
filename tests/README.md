# Headless tests

The pure shared modules — `Config`, `Economy`, `Balance` and the themes — don't
touch the DataModel, so they can be run outside Studio. That catches the class
of bug Studio only shows by playing for twenty minutes: index arithmetic, drop
odds, craft ceilings, quest rollover.

It has caught four real bugs so far, including a crafting exploit that turned a
single cheap variant into a top-tier unit.

## Running them

Needs the standalone Luau interpreter, which isn't in `rokit.toml` because its
release is a zip this machine has no `unzip` for:

```bash
cd /tmp && curl -sSfL -o luau.zip \
  https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/luau.zip').extractall('/tmp')"
chmod +x /tmp/luau
```

Then, from the repo root:

```bash
python3 tests/build.py /tmp && /tmp/luau /tmp/run.luau
```

## How it works

Roblox isn't available, so `stubs.luau` provides just enough of it: `Color3`
(with `:Lerp`), `Enum` as a metatable that answers any member, `Font.fromEnum`
and `Vector3`.

The modules use `require(script.Parent.X)`, which isn't a path. `build.py` wraps
each module's source in `function(script, require)` and `runtime.luau` hands it
a fake instance tree with `FindFirstChild` and `IsA`, so the requires resolve
the way Rojo would lay them out.

`tests.luau` is the assertions. It prints `n / n checks passed` and exits
non-zero if any fail.

## Worth testing here

Anything where being wrong is arithmetic rather than visual. Anything visual —
a tint, a layout, a glow — still needs Studio.

To test a theme or a config other than the shipped one, edit the generated
`run.luau`: it's a single concatenated file, so `Theme = "Squishies"` and the
`Variants`/`Sparkles` tables can be swapped in place before running it.
