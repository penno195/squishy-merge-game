#!/usr/bin/env node
// Turn a Claude Design 3D model into an OBJ + MTL that Studio's Import 3D takes.
//
// A design's model is a three.js script that builds a Group and hands it to its
// <three-d-stage> viewer. This runs that script unchanged against a stand-in
// stage, so the mesh is exactly what the design showed -- no hand-copied
// numbers to drift -- then shapes it for Roblox:
//
// - The design turns the model to face its viewer's camera. That turn is
//   dropped, leaving the face on +Z. Import 3D turns a model half round on the
//   way in, so that lands it facing -Z, which is Roblox's front.
// - Meshes sharing a material are merged into one part, named from PARTS
//   below. Every part is a separate asset upload in Studio, so six blush
//   strokes should be one part, not six.
// - Units are the design's own: the bun is 1 wide, the same as
//   ButterSquishy, so a theme's `Scale` means the same thing for both.
//
//     npm install --prefix /tmp/three three@0.184.0
//     THREE_DIR=/tmp/three/node_modules/three node scripts/export-design-model.mjs \
//         assets/source/SakuraSquishyBun/squishy-bun.js SakuraSquishyBun
//
// Then in Studio: File > Import 3D the OBJ -- copy it to a plain C:\ folder
// and browse to it; pasting the path has crashed the file picker -- and run the
// snippet at the bottom of the .mtl on the imported model to name, colour and
// mark it for tinting, and to record the outline the feature vocabulary in
// UnitVisuals dresses it by.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";

// Design material name -> Roblox part name, plus what the part should be in
// Studio. `Tint` parts take the unit's colour, darkened by the given amount, so
// one mesh serves every tier; the rest keep the design's colour.
const PARTS = {
	jelly_blue: { name: "Body", tint: 0 },
	jelly_knot: { name: "Knot", tint: 0.07 },
	eye_black: { name: "Eyes" },
	eye_shine: { name: "EyeShine" },
	mouth_dark: { name: "Mouth" },
	blush_pink: { name: "Blush" },
};

const [designPath, outName] = process.argv.slice(2);
if (!designPath || !outName) {
	console.error("usage: node scripts/export-design-model.mjs <design model .js> <OutName>");
	process.exit(2);
}
const threeDir = process.env.THREE_DIR;
if (!threeDir) {
	console.error("THREE_DIR must point at an installed three@0.184.0 (see the header of this script)");
	process.exit(2);
}
const threeUrl = (path) => pathToFileURL(join(threeDir, path)).href;
const THREE = await import(threeUrl("build/three.module.js"));
const { mergeGeometries } = await import(threeUrl("examples/jsm/utils/BufferGeometryUtils.js"));
const { OBJExporter } = await import(threeUrl("examples/jsm/exporters/OBJExporter.js"));

// The design only ever asks the page for its stage, waits on `ready` and calls
// `setObject`, so that is all the stand-in does.
let model = null;
globalThis.document = {
	querySelector: () => ({
		ready: Promise.resolve({ THREE }),
		setObject: (object) => {
			model = object;
		},
	}),
};
// Imported from source text so the design file needs no package.json or
// extension tricks to be read as a module (it uses top-level await).
const source = readFileSync(designPath, "utf8");
await import("data:text/javascript;base64," + Buffer.from(source).toString("base64"));
if (!model) {
	console.error(`${designPath} never called stage.setObject`);
	process.exit(1);
}

model.rotation.set(0, 0, 0);
model.updateMatrixWorld(true);

const byMaterial = new Map();
model.traverse((object) => {
	if (!object.isMesh) return;
	const key = object.material.name;
	if (!PARTS[key]) throw new Error(`material "${key}" has no entry in PARTS`);
	if (!byMaterial.has(key)) byMaterial.set(key, { material: object.material, geometries: [] });
	byMaterial.get(key).geometries.push(object.geometry.clone().applyMatrix4(object.matrixWorld));
});

const out = new THREE.Group();
const box = new THREE.Box3();
let triangles = 0;
for (const [key, { material, geometries }] of byMaterial) {
	const merged = mergeGeometries(geometries);
	if (!merged) throw new Error(`could not merge the "${key}" meshes`);
	const mesh = new THREE.Mesh(merged, material.clone());
	mesh.name = PARTS[key].name;
	mesh.material.name = PARTS[key].name;
	out.add(mesh);
	merged.computeBoundingBox();
	box.union(merged.boundingBox);
	const count = merged.index ? merged.index.count : merged.attributes.position.count;
	triangles += count / 3;
	console.log(`${mesh.name.padEnd(9)} ${geometries.length} mesh(es), ${count / 3} tris`);
}

// The outline UnitVisuals needs to put ears, snouts and crowns on this model
// rather than in the air round it: how wide the body is up its height, and where
// the face sits on it. Heights are fractions of the body's height from its base,
// half-widths fractions of its full width. Averaged round the body, so folds and
// ridges come out as the surface they wrap rather than as their peaks.
const PROFILE_SAMPLES = 21;
const partMesh = (name) => out.children.find((m) => m.name === name);
const bodyMesh = partMesh("Body");
if (!bodyMesh) throw new Error('no part is named "Body", so there is no outline to measure');
const bodyBox = bodyMesh.geometry.boundingBox;
const bodyHeight = bodyBox.max.y - bodyBox.min.y;
const bodyWidth = bodyBox.max.x - bodyBox.min.x;
const centreX = (bodyBox.max.x + bodyBox.min.x) / 2;
const centreZ = (bodyBox.max.z + bodyBox.min.z) / 2;
// Mean distance from the axis at each height the mesh has vertices at, then
// read off between those at evenly spaced heights -- a lathe has only a handful
// of rings, so fixed bands would mostly come up empty.
const bodyPositions = bodyMesh.geometry.attributes.position;
const rings = new Map();
for (let v = 0; v < bodyPositions.count; v++) {
	const r = Math.hypot(bodyPositions.getX(v) - centreX, bodyPositions.getZ(v) - centreZ);
	if (r < 1e-4) continue; // a lathe's pole vertex is on the axis, not the surface
	const key = Math.round(bodyPositions.getY(v) * 1e4);
	const ring = rings.get(key) ?? { total: 0, count: 0 };
	ring.total += r;
	ring.count++;
	rings.set(key, ring);
}
const ringList = [...rings]
	.map(([key, { total, count }]) => ({ t: (key / 1e4 - bodyBox.min.y) / bodyHeight, r: total / count / bodyWidth }))
	.sort((a, b) => a.t - b.t);
const profile = [];
for (let i = 0; i < PROFILE_SAMPLES; i++) {
	const t = i / (PROFILE_SAMPLES - 1);
	const above = ringList.findIndex((ring) => ring.t >= t);
	if (above <= 0) {
		profile.push(ringList[above === 0 ? 0 : ringList.length - 1].r);
		continue;
	}
	const lo = ringList[above - 1];
	const hi = ringList[above];
	profile.push(lo.r + ((hi.r - lo.r) * (t - lo.t)) / (hi.t - lo.t || 1));
}
const heightOf = (name) => {
	const mesh = partMesh(name);
	if (!mesh) return undefined;
	const box = mesh.geometry.boundingBox;
	return ((box.max.y + box.min.y) / 2 - bodyBox.min.y) / bodyHeight;
};
const outline = {
	BodyProfile: profile.map((r) => r.toFixed(3)).join(","),
	EyeHeight: Number(heightOf("Eyes")?.toFixed(3)),
	MouthHeight: Number(heightOf("Mouth")?.toFixed(3)),
};
console.log("outline", outline);

const outDir = dirname(designPath);
mkdirSync(outDir, { recursive: true });
// three writes each part as an `o` object, but Studio's importer splits on `g`
// groups: with only `o` lines it lumps everything into one MeshPart called
// "default", and a single MeshPart can only be one colour. So each object gets a
// matching group.
const obj = new OBJExporter().parse(out).replace(/^o (.+)$/gm, "o $1\ng $1");
writeFileSync(join(outDir, `${outName}.obj`), `mtllib ${outName}.mtl\n` + obj);

// Roblox's importer may or may not carry Kd across, so the MTL also holds a
// command-bar snippet that sets every part up by name. It rides in comments,
// which OBJ readers skip.
// three keeps colours linear internally; Roblox and MTL files both mean sRGB.
const srgb = (color) => color.getRGB({}, THREE.SRGBColorSpace);
const rgb = (color) => {
	const c = srgb(color);
	return [c.r, c.g, c.b].map((v) => Math.round(v * 255)).join(", ");
};
let mtl = `# ${outName}, exported from ${designPath.split("/").pop()} by scripts/export-design-model.mjs\n\n`;
for (const mesh of out.children) {
	const { color, roughness } = mesh.material;
	const c = srgb(color);
	mtl += `newmtl ${mesh.name}\n`;
	mtl += `Kd ${c.r.toFixed(4)} ${c.g.toFixed(4)} ${c.b.toFixed(4)}\n`;
	mtl += `Ks 0.2000 0.2000 0.2000\nNs ${Math.round((1 - roughness) * 200)}\nd 1.0000\n\n`;
}
mtl += "# Studio setup -- select the imported model, then paste into the command bar:\n#\n";
mtl += `#   local model = game.Selection:Get()[1]\n#   model.Name = "${outName}"\n`;
mtl += "#   local parts = {\n";
for (const [key, part] of Object.entries(PARTS)) {
	if (!byMaterial.has(key)) continue;
	const mesh = out.children.find((m) => m.name === part.name);
	const tint = part.tint === undefined ? "nil" : String(part.tint);
	mtl += `#     ${part.name} = { Color = Color3.fromRGB(${rgb(mesh.material.color)}), Tint = ${tint} }, -- #${mesh.material.color.getHexString()}\n`;
}
mtl += "#   }\n";
mtl += "#   for _, p in model:GetDescendants() do\n";
mtl += "#     local spec = p:IsA(\"BasePart\") and parts[p.Name]\n";
mtl += "#     if spec then p.Color = spec.Color; p.Material = Enum.Material.SmoothPlastic; p:SetAttribute(\"Tint\", spec.Tint) end\n";
mtl += "#   end\n";
for (const [name, value] of Object.entries(outline)) {
	if (typeof value === "number" && Number.isNaN(value)) continue;
	mtl += `#   model:SetAttribute("${name}", ${typeof value === "string" ? `"${value}"` : value})\n`;
}
writeFileSync(join(outDir, `${outName}.mtl`), mtl);

const size = box.getSize(new THREE.Vector3());
console.log(
	`${triangles} tris total; ${size.x.toFixed(3)} x ${size.y.toFixed(3)} x ${size.z.toFixed(3)}, ` +
		`y ${box.min.y.toFixed(3)}..${box.max.y.toFixed(3)}`,
);
