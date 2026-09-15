import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
# Which file goes on the end. tests.luau asserts; sim.luau measures. Both read
# the same modules through the same fake require tree.
ENTRY = sys.argv[2] if len(sys.argv) > 2 else "tests.luau"
OUT_NAME = "run.luau" if ENTRY == "tests.luau" else "sim-run.luau"

MODULES = {
	"Shared/Balance": "src/shared/Balance.luau",
	"Shared/Settings": "src/shared/Settings.luau",
	"Shared/Types": "src/shared/Types.luau",
	"Shared/Config": "src/shared/Config.luau",
	"Shared/Economy": "src/shared/Economy.luau",
	"Shared/Themes/Squishies": "src/shared/Themes/Squishies.luau",
	"Shared/Themes/CandyLand": "src/shared/Themes/CandyLand.luau",
}

out = []
out.append(open(os.path.join(HERE, "stubs.luau")).read())
out.append("local loaders = {}\n")
for name, path in MODULES.items():
	src = open(os.path.join(ROOT, path)).read()
	# --!strict is a comment, harmless inside a function body.
	out.append(f'loaders["{name}"] = function(script, require)\n{src}\nend\n')
out.append(open(os.path.join(HERE, "runtime.luau")).read())
out.append(open(os.path.join(HERE, ENTRY)).read())
open(os.path.join(OUT, OUT_NAME), "w").write("\n".join(out))
print(f"built {OUT_NAME} from {ENTRY}")
