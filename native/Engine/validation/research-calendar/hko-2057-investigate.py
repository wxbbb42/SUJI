#!/usr/bin/env python3
"""Read-only investigation of the 2057 HKO near-midnight new moon.

Requires existing Engine deps, astronomy-engine 2.1.19, skyfield 1.54,
and Poppler. Downloads stay in ignored hko-cache/. No production code,
original result, or output file is overwritten. See the resolution report.
"""
import argparse
import datetime as dt
import hashlib
import importlib.metadata
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.request import Request, urlopen

HERE = Path(__file__).resolve().parent
ENGINE = HERE.parents[1]
CACHE = HERE / 'hko-cache' / '2057-investigation'
SOURCES = {
    'hko-conversion.html': 'https://www.hko.gov.hk/en/gts/time/conversion.htm',
    'hko-conversion-zh.html': 'https://www.hko.gov.hk/tc/gts/time/conversion.htm',
    'hko-T2057e.txt': 'https://www.hko.gov.hk/en/gts/time/calendar/text/files/T2057e.txt',
    'hko-2057e-current.pdf': 'https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/2057e.pdf',
    'nasa-phases2001.html': 'https://eclipse.gsfc.nasa.gov/phase/phases2001.html',
    'nasa-deltatpoly.html': 'https://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html',
    'jpl-de440s.bsp': 'https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de440s.bsp',
    'skyfield-time.html': 'https://rhodesmill.org/skyfield/time.html',
    'jpl-de440.html': 'https://ssd.jpl.nasa.gov/planets/eph_export.html',
}

NODE = r'''
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const engine=process.argv[1],refs=process.argv[2];
const source=path.join(engine,'node_modules/lunar-javascript/lunar.js');
const {Solar,ShouXingUtil:S}=require(source);
const A=require(path.join(refs,'astronomy-engine'));
const jd=Solar.fromYmdHms(2057,9,28,0,0,0).getJulianDay();
const w=Math.floor((jd+14-2451551)/29.5306)*Math.PI*2;
const tt=S.msaLonT(w)*36525,ut=S.shuoHigh(w)-1/3;
const fastTT=S.msaLonT2(w)*36525;
const deltaTInHigh=S.dtT(fastTT-S.dtT(fastTT)+1/3)*86400;
const phase=A.SearchMoonPhase(0,new Date('2057-09-27T00:00:00Z'),4);
const toCalendar=days=>new Date((days+2451545-2440587.5)*86400000).toISOString().replace('Z','');
const dates=[];
for(let t=Date.parse('2057-09-27T00:00:00Z');t<=Date.parse('2057-10-28T00:00:00Z');t+=86400000){
 const d=new Date(t),l=Solar.fromYmdHms(2057,d.getUTCMonth()+1,d.getUTCDate(),12,0,0).getLunar();
 dates.push({date:d.toISOString().slice(0,10),year:l.getYear(),month:l.getMonth(),day:l.getDay()});
}
console.log(JSON.stringify({
 lunar:{version:require(path.join(engine,'node_modules/lunar-javascript/package.json')).version,
 sourceSha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),
 ttJD:tt+2451545,ttCalendar:toCalendar(tt),deltaTSeconds:deltaTInHigh,
 utJD:ut+2451545,utCalendar:toCalendar(ut),utPlus08Calendar:toCalendar(ut+1/3),
 highPrecisionFallbackUsed:Math.abs(ut-(fastTT-S.dtT(fastTT)))>1e-8},
 astronomyEngine:{version:require(path.join(refs,'astronomy-engine/package.json')).version,
 ttJD:phase.tt+2451545,ttCalendar:toCalendar(phase.tt),deltaTSeconds:(phase.tt-phase.ut)*86400,
 utJD:phase.ut+2451545,utCalendar:toCalendar(phase.ut),utPlus08Calendar:toCalendar(phase.ut+1/3)},dates}));
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def calendar(jd):
    return (dt.datetime(2000, 1, 1, 12) + dt.timedelta(days=jd - 2451545)).isoformat(timespec='milliseconds')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true', help='download missing fixed sources, never replace cache')
    parser.add_argument('--output', required=True, type=Path, help='new immutable JSON result path')
    args = parser.parse_args()
    if args.output.exists():
        parser.error('output exists; choose a new path to preserve evidence')
    CACHE.mkdir(parents=True, exist_ok=True)
    existing_records = []
    for path in sorted(CACHE.glob('sources-*.json')):
        existing_records.extend(json.loads(path.read_text()))
    records = []
    for name, url in SOURCES.items():
        path = CACHE / name
        matches = [r for r in existing_records if r.get('url') == url and r.get('sha256')]
        if not path.exists():
            if not args.fetch:
                parser.error(f'missing {name}; use --fetch')
            with urlopen(Request(url, headers={'User-Agent': 'SUJI-calendar-reference-research'}), timeout=55) as response:
                payload = response.read()
                record = {'url': url, 'retrievedUTC': dt.datetime.now(dt.timezone.utc).isoformat(),
                          'headers': dict(response.headers), 'status': response.status, 'path': str(path.relative_to(ENGINE))}
            path.write_bytes(payload)
        else:
            record = dict(matches[-1]) if matches else {'url': url, 'retrievedUTC': None, 'path': str(path.relative_to(ENGINE))}
        actual_hash = sha(path)
        if record.get('sha256') and actual_hash != record['sha256']:
            raise ValueError(f'cached source hash changed: {name}')
        record.update(file=name, bytes=path.stat().st_size, sha256=actual_hash)
        # Absolute machine paths and transient HTTP request ids are not evidence.
        record['path'] = str(path.relative_to(ENGINE))
        record['headers'] = {k: v for k, v in record.get('headers', {}).items()
                             if k.lower() in ('last-modified', 'etag', 'content-type', 'date')}
        records.append(record)

    spec = importlib.util.spec_from_file_location('hko_audit', HERE / 'hko-daily-audit.py')
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    bbox = CACHE / 'hko-2057e-investigation.html'
    subprocess.run(['pdftotext', '-bbox-layout', str(CACHE / 'hko-2057e-current.pdf'), str(bbox)], check=True)
    pdf_rows = audit.parse_pdf_year(2057, bbox)
    txt_rows = audit.parse_official_text(2057, CACHE / 'hko-T2057e.txt')
    if pdf_rows != txt_rows:
        raise ValueError('official PDF/TXT disagree; investigate before continuing')
    metadata = subprocess.check_output(['pdfinfo', str(CACHE / 'hko-2057e-current.pdf')], text=True)
    old_manifest = json.loads((HERE / 'hko-daily-manifest.json').read_text())
    old_record = next(r for r in old_manifest['files'] if r['year'] == 2057)
    html = (CACHE / 'hko-conversion-zh.html').read_text()
    disclaimer = re.search(r'<li>(由於計算數十年後[^<]+)</li>', html).group(1)
    assert '2057年9月28日' in disclaimer
    nasa = (CACHE / 'nasa-phases2001.html').read_text()
    nasa_year = re.search(r'^ 2057\s+Jan[^\n]+\n(?:.*\n){12}', nasa, re.M).group(0)
    nasa_lines = [line for line in nasa_year.splitlines() if re.search(r'2057|Sep 28|Oct 28', line)]
    native = json.loads(subprocess.check_output(['node', '-e', NODE, str(ENGINE),
        os.environ.get('SUJI_CALENDAR_REFS', '/tmp/suji-calendar-research/node_modules')], text=True))

    from skyfield import almanac
    from skyfield.api import load, load_file
    import skyfield
    eph = load_file(str(CACHE / 'jpl-de440s.bsp'))
    ts = load.timescale(builtin=True)  # Reproducible package data; no implicit network updates.
    times, phases = almanac.find_discrete(ts.tt(2057, 9, 27), ts.tt(2057, 9, 30), almanac.moon_phases(eph))
    assert len(times) == 1 and int(phases[0]) == 0
    instant = times[0]
    precise = {'version': skyfield.__version__, 'ephemeris': 'JPL DE440s',
               'algorithm': 'skyfield.almanac.moon_phases: apparent geocentric ecliptic longitudes of date',
               'ttJD': float(instant.tt), 'ttCalendar': calendar(float(instant.tt)),
               'deltaTSeconds': float(instant.delta_t), 'ut1JD': float(instant.ut1),
               'ut1Calendar': calendar(float(instant.ut1)), 'ut1Plus08Calendar': calendar(float(instant.ut1) + 1/3),
               'phaseDegreesAtRoot': float(almanac.moon_phase(eph, instant).degrees)}
    midnight_ut_jd = 2472635 + 1/6  # 2057-09-28 16:00 UT = next midnight at UT+08.
    threshold = (precise['ttJD'] - midnight_ut_jd) * 86400
    sensitivity = []
    for name, delta in [('skyfield', precise['deltaTSeconds']), ('lunar-javascript', native['lunar']['deltaTSeconds']),
                        ('Espenak-Meeus/astronomy-engine', native['astronomyEngine']['deltaTSeconds']),
                        ('illustrative 120 seconds; not an HKO parameter', 120)]:
        shifted = precise['ttJD'] - delta / 86400 + 1/3
        sensitivity.append({'deltaTModel': name, 'deltaTSeconds': delta, 'fixedDE440ttUTPlus08': calendar(shifted),
                            'secondsAfterMidnight': threshold - delta})
    official = {x['date']: x for x in pdf_rows}
    comparisons = []
    for actual in native.pop('dates'):
        expected = official[actual['date']]
        comparisons.append({'date': actual['date'], 'officialDay': expected['day'],
                            'officialNewMonthMarker': expected['newMonth'], 'lunarJavascript': actual,
                            'dayMatches': expected['day'] == actual['day']})
    old = json.loads((HERE / 'hko-daily-results.json').read_text())['mismatches']
    new_dates = {r['date'] for r in comparisons if not r['dayMatches']}
    assert new_dates == {r['date'] for r in old}
    result = {
        'generatedUTC': dt.datetime.now(dt.timezone.utc).isoformat(), 'scriptSha256': sha(Path(__file__)),
        'scope': '2057-09-27 to 2057-10-28, one conjunction; no production mutation or 200-year rerun',
        'sources': records, 'failedSourceAttempts': [r for r in existing_records if r.get('error')],
        'hko': {'officialPDFMatchesPreviousAudit': sha(CACHE / 'hko-2057e-current.pdf') == old_record['pdfSha256'],
                'pdfTextAll365CellsAgree': True, 'pdfMetadata': metadata, 'officialDisclaimer': disclaimer},
        'nasaPublishedMinutePrecision': {'source': SOURCES['nasa-phases2001.html'], 'lines': nasa_lines,
             'interpretation': '16:00 UT is the date boundary at UT+08; rounded minutes cannot decide its side. Annual 00h02m is also rounded; do not use as exact delta T.'},
        **native, 'skyfieldDE440s': precise,
        'sameTimeScaleDifferencesSeconds': {
            'lunarTTMinusDE440TT': (native['lunar']['ttJD'] - precise['ttJD']) * 86400,
            'astronomyEngineTTMinusDE440TT': (native['astronomyEngine']['ttJD'] - precise['ttJD']) * 86400},
        'deltaTThresholdForDE440RootToFallBeforeMidnightSeconds': threshold,
        'fixedEphemerisDeltaTSensitivity': sensitivity, 'boundaryComparisons': comparisons,
        'dependencyVersions': {name: importlib.metadata.version(name) for name in ['skyfield', 'jplephem', 'numpy', 'sgp4']},
        'limits': ['Future UT1 and UTC are not interchangeable exact known quantities. TT calendar strings are time-scale coordinates, not UTC timestamps.',
                   'No HKO exact 2057 conjunction time or its original ephemeris/delta-T parameter was found; numerical attribution to its particular model remains unproven.',
                   'The synthetic 120-second delta-T scenario is a sensitivity example, not an official HKO setting or a confidence interval.',
                   'Subsecond numerical root agreement is not a demonstrated universal error bound. No future Earth-rotation prediction is proven by this comparison.'],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps({'result': str(args.output), 'pdfTxtAgree': True, 'disagreementDays': len(new_dates),
                      'de440UT1Plus08': precise['ut1Plus08Calendar'], 'deltaTThresholdSeconds': threshold}))


if __name__ == '__main__':
    main()
