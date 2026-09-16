const stage = document.querySelector('three-d-stage');
const { THREE: T } = await stage.ready;

/* ---------- silhouette: hand-authored bun profile (r, y) top → base ---------- */
const PROFILE = [
  [0.040, 0.342], [0.105, 0.334], [0.185, 0.316], [0.268, 0.288],
  [0.345, 0.248], [0.412, 0.194], [0.462, 0.126], [0.492, 0.048],
  [0.500, -0.040], [0.487, -0.126], [0.452, -0.198], [0.392, -0.254],
  [0.298, -0.292], [0.170, -0.305], [0.000, -0.305]
];
const SEG = 64;      // radial segments — smooth shell, 4 per fold
const RIDGES = 16;   // gathered folds, 2 segments each → crisp alternating creases
const BASE_Y = -0.305;

const radiusAt = (y) => {
  if (y >= PROFILE[0][1]) return PROFILE[0][0];
  for (let i = 0; i < PROFILE.length - 1; i++) {
    const [r0, y0] = PROFILE[i], [r1, y1] = PROFILE[i + 1];
    if (y <= y0 && y >= y1) {
      const t = (y0 - y) / (y0 - y1 || 1);
      return r0 + (r1 - r0) * t;
    }
  }
  return 0;
};

const mats = {
  jelly: new T.MeshStandardMaterial({
    name: 'jelly_blue', color: 0x6ecdf0, roughness: 0.38, metalness: 0.0
  }),
  knot: new T.MeshStandardMaterial({ name: 'jelly_knot', color: 0x5cc2ea, roughness: 0.42 }),
  eye: new T.MeshStandardMaterial({ name: 'eye_black', color: 0x15121a, roughness: 0.42 }),
  shine: new T.MeshStandardMaterial({ name: 'eye_shine', color: 0xffffff, roughness: 0.45 }),
  mouth: new T.MeshStandardMaterial({ name: 'mouth_dark', color: 0x1a1016, roughness: 0.3 }),
  blush: new T.MeshStandardMaterial({ name: 'blush_pink', color: 0xff6f9c, roughness: 0.55 })
};

const model = new T.Group();
model.name = 'squishy_bun';

/* ---------- body ---------- */
const bodyGeo = new T.LatheGeometry(
  PROFILE.slice().reverse().map(([r, y]) => new T.Vector2(r, y)), SEG
);
{
  const p = bodyGeo.attributes.position;
  const v = new T.Vector3();
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const r = Math.hypot(v.x, v.z);
    if (r < 1e-5) continue;
    const theta = Math.atan2(v.z, v.x);
    // folds gather toward the top, vanish below the belly line
    const up = Math.max(0, (v.y + 0.06) / (0.342 + 0.06));
    const amp = 0.085 * Math.pow(up, 0.85) * Math.cos(RIDGES * theta);
    const k = 1 + amp;
    p.setXYZ(i, v.x * k, v.y, v.z * k);
  }
  bodyGeo.computeVertexNormals();
  // weld the lathe seam: phi=0 and phi=2pi columns share positions but get
  // mirrored normals from computeVertexNormals, which reads as a hard crease
  const n = bodyGeo.attributes.normal;
  const rings = PROFILE.length;
  for (let j = 0; j < rings; j++) {
    const a = j, b = SEG * rings + j;
    const nx = (n.getX(a) + n.getX(b)) / 2;
    const ny = (n.getY(a) + n.getY(b)) / 2;
    const nz = (n.getZ(a) + n.getZ(b)) / 2;
    const L = Math.hypot(nx, ny, nz) || 1;
    n.setXYZ(a, nx / L, ny / L, nz / L);
    n.setXYZ(b, nx / L, ny / L, nz / L);
  }
  n.needsUpdate = true;
}
const body = new T.Mesh(bodyGeo, mats.jelly);
body.name = 'body';
model.add(body);

/* ---------- gathered top knot ---------- */
const knot = new T.Mesh(new T.CylinderGeometry(0.052, 0.088, 0.075, 8), mats.knot);
knot.name = 'top_knot';
knot.position.y = 0.335;
knot.rotation.y = Math.PI / 16;
model.add(knot);

const knotCap = new T.Mesh(new T.SphereGeometry(0.052, 8, 5, 0, Math.PI * 2, 0, Math.PI / 2), mats.knot);
knotCap.name = 'knot_tip';
knotCap.position.y = 0.372;
knotCap.scale.set(1, 0.55, 1);
model.add(knotCap);

/* ---------- face helpers: seat features on the shell ---------- */
// radius of the DISPLACED shell, solved for the decal's own angle
const pleatK = (theta, y) => {
  const up = Math.max(0, (y + 0.06) / (0.342 + 0.06));
  return 1 + 0.085 * Math.pow(up, 0.85) * Math.cos(RIDGES * theta);
};
const frontZ = (x, y) => {
  const r0 = radiusAt(y);
  let z = Math.sqrt(Math.max(0.0004, r0 * r0 - x * x));
  for (let i = 0; i < 4; i++) {
    const r = r0 * pleatK(Math.atan2(z, x), y);
    z = Math.sqrt(Math.max(0.0004, r * r - x * x));
  }
  return z;
};
// seat a decal at a given azimuth off the front axis — the pleat factor is
// exact here because theta = 90deg - azimuth, no solving needed
const seatPolar = (mesh, azDeg, y, lift) => {
  const az = azDeg * Math.PI / 180;
  const r = radiusAt(y) * pleatK(Math.PI / 2 - az, y) + lift;
  const x = Math.sin(az) * r, z = Math.cos(az) * r;
  mesh.position.set(x, y, z);
  mesh.lookAt(x * 2.4, y, z * 2.4);
};
const seat = (mesh, x, y, lift) => {
  const z = frontZ(x, y);
  mesh.position.set(x, y, z + lift);
  mesh.lookAt(x * 2.4, y, z * 2.4);
};

/* eyes: beads seated two-thirds out of the shell, highlight fixed on the bead */
for (const s of [-1, 1]) {
  const ex = 0.140 * s, ey = 0.020, R = 0.082;
  const eye = new T.Mesh(new T.SphereGeometry(R, 16, 12), mats.eye);
  eye.name = s < 0 ? 'eye_left' : 'eye_right';
  const z = frontZ(ex, ey);
  eye.position.set(ex * 0.985, ey, z - R * 0.42);
  model.add(eye);

  const shine = new T.Mesh(new T.SphereGeometry(0.021, 10, 8), mats.shine);
  shine.name = s < 0 ? 'eye_shine_left' : 'eye_shine_right';
  const d = new T.Vector3(-0.40 * s, 0.52, 0.76).normalize(); // mirrored glint, inboard-upper on each bead
  shine.position.copy(eye.position).add(d.multiplyScalar(R * 0.94));
  shine.lookAt(eye.position.x + d.x * 3, eye.position.y + d.y * 3, eye.position.z + d.z * 3);
  shine.scale.set(1.05, 1.05, 0.45);
  model.add(shine);
}

/* smile: thin arc hugging the shell */
const mouth = new T.Mesh(new T.TorusGeometry(0.058, 0.014, 6, 16, Math.PI), mats.mouth);
mouth.name = 'mouth';
seat(mouth, 0, -0.103, -0.004);
mouth.rotateZ(Math.PI);
model.add(mouth);

/* blush: flat decals conformed to the shell — no protruding blobs */
for (const s of [-1, 1]) {
  const stroke = new T.CircleGeometry(0.010, 8);
  for (let i = 0; i < 3; i++) {
    const m = new T.Mesh(stroke, mats.blush);
    m.name = (s < 0 ? 'blush_left_' : 'blush_right_') + (i + 1);
    seatPolar(m, (27 + i * 5.5) * s, -0.078 - i * 0.012, 0.006);
    m.scale.set(1.0, 2.3, 1.0);
    m.rotateZ(0.32 * s);
    model.add(m);
  }
}

model.position.y = -BASE_Y;
model.rotation.y = Math.atan2(1, 1.25); // face the stage's default camera
stage.setObject(model);
