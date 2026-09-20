// Research only. This does not register a production engine command.
// Usage: node sample.cjs /absolute/path/to/astronomy-engine output-directory
const fs = require('node:fs');
const path = require('node:path');
const { performance } = require('node:perf_hooks');
const [library, output] = process.argv.slice(2);
if (!library || !output) throw new Error('Expected library directory and output directory');
const A = require(path.resolve(library));
const pkg = require(path.resolve(library, 'package.json'));
if (pkg.version !== '2.1.19') throw new Error('This probe is pinned to astronomy-engine 2.1.19');
fs.mkdirSync(output, { recursive: true });
const bodies = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];
const rows = [];
const started = performance.now();
for (let year = 1901; year <= 2100; year++) {
  for (const month of [1, 4, 7, 10]) {
    const instant = `${year}-${String(month).padStart(2, '0')}-15T04:00:00Z`;
    const time = A.MakeTime(new Date(instant));
    for (const body of bodies) {
      const vector = A.GeoVector(body, time, true);
      const ecliptic = A.Ecliptic(vector);
      const equator = A.EquatorFromVector(A.RotateVector(A.Rotation_EQJ_EQD(time), vector));
      rows.push({ instant, body, julianDayUT: time.ut + 2451545,
        julianDayTT: time.tt + 2451545, deltaTSeconds: (time.tt - time.ut) * 86400,
        longitude: ecliptic.elon, latitude: ecliptic.elat,
        rightAscensionDegrees: equator.ra * 15, declination: equator.dec });
    }
  }
}
fs.writeFileSync(path.join(output, 'candidate.json'), JSON.stringify(rows));
console.log(JSON.stringify({ samples: rows.length, calculationMilliseconds: performance.now() - started }));
