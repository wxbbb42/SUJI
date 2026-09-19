#!/usr/bin/env python3
"""Independent HKO PDF extraction, bounded to 200 official 1901–2100 files.

Requires curl and Poppler pdftotext. Caches ignored PDFs/bounding-box extraction;
persists provenance, failures, daily coverage, and an independent oracle in cache.
This script never imports a lunar calculation library.
"""
import argparse
import calendar
import concurrent.futures
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
CACHE = HERE / 'hko-cache'
MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']


def parse_pdf_year(year, bbox):
    words = []
    for item in ET.parse(bbox).iter():
        if not item.tag.endswith('word'):
            continue
        words.append({'text': item.text or '', 'x': (float(item.attrib['xMin']) + float(item.attrib['xMax'])) / 2,
                      'y': (float(item.attrib['yMin']) + float(item.attrib['yMax'])) / 2})
    month_labels = []
    label_right = min(w['x'] for w in words if w['text'] == 'Jan') + 12
    for label in MONTHS:
        matches = [w for w in words if w['text'] == label and w['x'] <= label_right]
        if len(matches) != 1:
            raise ValueError(f'{label}: expected one row label, found {len(matches)}')
        month_labels.append(matches[0])
    if any(b['y'] <= a['y'] for a, b in zip(month_labels, month_labels[1:])):
        raise ValueError('month labels not in chronological vertical order')
    # Locate all 31 column centers from the header, never from a lunar library.
    header = None
    for one in [w for w in words if w['text'] == '1' and w['y'] < month_labels[0]['y'] - 8]:
        row = [w for w in words if abs(w['y'] - one['y']) < 1.5 and w['text'].isdigit()]
        if len(row) == 31 and {int(w['text']) for w in row} == set(range(1, 32)):
            header = sorted(row, key=lambda w: int(w['text']))
            break
    if header is None:
        raise ValueError('could not establish all 31 Gregorian column centers')
    centers = [w['x'] for w in header]
    steps = [b - a for a, b in zip(centers, centers[1:])]
    if min(steps) <= 0 or max(steps) / min(steps) > 1.25:
        raise ValueError('nonuniform Gregorian column spacing')
    left, right = centers[0] - steps[0] / 2, centers[-1] + steps[-1] / 2
    rows = []
    for month, label in enumerate(month_labels, 1):
        lower = (month_labels[month - 2]['y'] + label['y']) / 2 if month > 1 else label['y'] - (month_labels[1]['y'] - label['y']) / 2
        upper = (label['y'] + month_labels[month]['y']) / 2 if month < 12 else label['y'] + (label['y'] - month_labels[-2]['y']) / 2
        cells = [[] for _ in range(31)]
        for w in words:
            if lower <= w['y'] < upper and left <= w['x'] <= right:
                index = min(range(31), key=lambda i: abs(centers[i] - w['x']))
                cells[index].append(w['text'])
        for day in range(1, calendar.monthrange(year, month)[1] + 1):
            tokens = cells[day - 1]
            ordinals = [int(m.group(1)) for token in tokens if (m := re.fullmatch(r'(\d+)(?:st|nd|rd|th)', token))]
            numbers = [int(t) for t in tokens if t.isdigit()]
            # A few official PDFs clip "Month" and wrap "Lunar" as Luna/r.
            # The unique ordinal + Lunar remains the printed first-day marker.
            non_ordinal_text = ''.join(t for t in tokens if not re.fullmatch(r'\d+(?:st|nd|rd|th)', t))
            if len(ordinals) == 1 and not numbers and 'Lunar' in non_ordinal_text:
                lunar_day, new_month = 1, ordinals[0]
                if not 1 <= new_month <= 12:
                    raise ValueError(f'{month}/{day}: invalid lunar month {new_month}')
            elif len(numbers) == 1 and not ordinals and 2 <= numbers[0] <= 30 and len(tokens) == 1:
                lunar_day, new_month = numbers[0], None
            else:
                raise ValueError(f'{month}/{day}: ambiguous PDF cell {tokens}')
            rows.append({'date': f'{year:04}-{month:02}-{day:02}', 'day': lunar_day, 'newMonth': new_month})
        if any(cells[calendar.monthrange(year, month)[1]:]):
            raise ValueError(f'{month}: unexpected content after last Gregorian day')
    for previous, current in zip(rows, rows[1:]):
        if current['day'] == 1:
            if previous['day'] not in (29, 30):
                raise ValueError(f"{current['date']}: lunar reset after {previous['day']}")
        elif current['day'] != previous['day'] + 1:
            raise ValueError(f"{current['date']}: discontinuous lunar day {previous['day']} -> {current['day']}")
    return rows


def load_year(year, refresh=False):
    url = f'https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/{year}e.pdf'
    pdf, bbox = CACHE / f'{year}e.pdf', CACHE / f'{year}e.html'
    result = {'year': year, 'url': url, 'status': 'pending', 'expectedDays': 366 if calendar.isleap(year) else 365}
    try:
        cached = pdf.exists() and pdf.read_bytes()[:5] == b'%PDF-'
        if refresh or not cached:
            temporary = pdf.with_suffix('.download')
            response = subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error', '--retry', '1', '--connect-timeout', '12', '--max-time', '40', url, '-o', str(temporary)], capture_output=True, text=True)
            if response.returncode:
                raise RuntimeError('download: ' + response.stderr.strip()[:500])
            if temporary.read_bytes()[:5] != b'%PDF-':
                raise RuntimeError('download did not return a PDF')
            temporary.replace(pdf)
            bbox.unlink(missing_ok=True)
        payload = pdf.read_bytes()
        result.update(bytes=len(payload), pdfSha256=hashlib.sha256(payload).hexdigest(), cached=cached and not refresh)
        try:
            if not bbox.exists():
                extraction = subprocess.run(['pdftotext', '-bbox-layout', str(pdf), str(bbox)], capture_output=True, text=True)
                if extraction.returncode:
                    raise RuntimeError('pdftotext: ' + extraction.stderr.strip()[:500])
            result['textSha256'] = hashlib.sha256(bbox.read_bytes()).hexdigest()
            rows = parse_pdf_year(year, bbox)
            result['extraction'] = 'pdf-bounding-boxes'
        except Exception as error:
            if bbox.exists():
                result['textSha256'] = hashlib.sha256(bbox.read_bytes()).hexdigest()
            result['pdfParseError'] = str(error)
            text_url = f'https://www.hko.gov.hk/en/gts/time/calendar/text/files/T{year}e.txt'
            source_text = CACHE / f'T{year}e.txt'
            if refresh or not source_text.exists():
                response = subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error', '--connect-timeout', '12', '--max-time', '40', text_url, '-o', str(source_text)], capture_output=True, text=True)
                if response.returncode:
                    raise RuntimeError('official text fallback: ' + response.stderr.strip()[:500])
            rows = parse_official_text(year, source_text)
            result.update(extraction='official-text-fallback', officialTextURL=text_url,
                          officialTextSha256=hashlib.sha256(source_text.read_bytes()).hexdigest())
        result.update(status='parsed', parsedDays=len(rows), firstDate=rows[0]['date'], lastDate=rows[-1]['date'])
        (CACHE / f'{year}-cells.json').write_text(json.dumps(rows, ensure_ascii=False))
        return result, rows
    except Exception as error:
        result.update(status='failed', error=str(error))
        return result, []


def parse_official_text(year, source_text):
    rows = []
    for line in source_text.read_text(encoding='utf-8', errors='replace').splitlines():
        match = re.match(r'^(\d{4})/(\d{1,2})/(\d{1,2})\s+(\d{1,2})(?:(st|nd|rd|th)\s+Lunar\s+Month)?\s+', line)
        if not match:
            continue
        y, m, d, number = map(int, match.groups()[:4])
        date = dt.date(y, m, d)
        if y != year:
            raise ValueError('unexpected year in official text fallback')
        if rows and date != dt.date.fromisoformat(rows[-1]['date']) + dt.timedelta(days=1):
            raise ValueError('nonconsecutive official Gregorian text rows')
        is_start = bool(match.group(5))
        if not 1 <= number <= (12 if is_start else 30):
            raise ValueError('invalid lunar value in official text fallback')
        rows.append({'date': date.isoformat(), 'day': 1 if is_start else number, 'newMonth': number if is_start else None})
    expected = 366 if calendar.isleap(year) else 365
    if len(rows) != expected or rows[0]['date'] != f'{year}-01-01' or rows[-1]['date'] != f'{year}-12-31':
        raise ValueError(f'official text fallback has {len(rows)}/{expected} days')
    for previous, current in zip(rows, rows[1:]):
        if (current['day'] == 1 and previous['day'] not in (29, 30)) or (current['day'] != 1 and current['day'] != previous['day'] + 1):
            raise ValueError(f"{current['date']}: official text lunar sequence is discontinuous")
    return rows


def assemble(records):
    """Infer leap months only from a repeated official month number in sequence.

    The initial partial lunar month lacks a printed month/leap label. Keep it
    explicitly unknown, rather than borrowing that fact from the tested library.
    """
    all_rows = sorted([row for _, rows in records for row in rows], key=lambda row: row['date'])
    result, month, lunar_year, leap = [], None, None, None
    previous = None
    errors = []
    for row in all_rows:
        date = dt.date.fromisoformat(row['date'])
        contiguous = previous is not None and date == dt.date.fromisoformat(previous['date']) + dt.timedelta(days=1)
        if not contiguous:
            month, lunar_year, leap = None, None, None
        if contiguous and row['day'] != (1 if previous['day'] in (29, 30) and row['day'] == 1 else previous['day'] + 1):
            errors.append({'date': row['date'], 'error': 'cross-file lunar day discontinuity', 'previous': previous['day'], 'actual': row['day']})
        if row['newMonth'] is not None:
            incoming = row['newMonth']
            if month is not None:
                if incoming == month and leap is False:
                    leap = True
                elif incoming == month % 12 + 1:
                    leap = False
                else:
                    errors.append({'date': row['date'], 'error': 'lunar month sequence discontinuity', 'previousMonth': month, 'actualMonth': incoming, 'previousLeap': leap})
                    leap = None
            else:
                # The first visible January start can be assumed regular only
                # when it is month 1: a leap month 1 would start after February.
                leap = False if incoming == 1 else None
            month = incoming
            if incoming == 1 and leap is False:
                lunar_year = date.year
            elif lunar_year is None:
                lunar_year = date.year - (1 if date.month <= 2 and incoming >= 11 else 0)
        result.append({'date': row['date'], 'lunarYear': lunar_year, 'lunarMonth': month,
                       'leap': leap, 'lunarDay': row['day'],
                       'fullDateEstablished': month is not None and lunar_year is not None and leap is not None})
        previous = row
    return result, errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--start', type=int, default=1901)
    parser.add_argument('--end', type=int, default=2100)
    parser.add_argument('--workers', type=int, default=6)
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    if not 1901 <= args.start <= args.end <= 2100:
        parser.error('only 1901–2100 is permitted; at most 200 PDFs')
    CACHE.mkdir(exist_ok=True)
    records = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, min(args.workers, 8))) as pool:
        futures = [pool.submit(load_year, year, args.refresh) for year in range(args.start, args.end + 1)]
        for future in concurrent.futures.as_completed(futures):
            record = future.result()
            records.append(record)
            if record[0]['status'] == 'failed' or len(records) % 10 == 0:
                print(json.dumps({'finished': len(records), 'total': len(futures), **record[0]}, ensure_ascii=False), flush=True)
    records.sort(key=lambda pair: pair[0]['year'])
    days, sequence_errors = assemble(records)
    (CACHE / 'official-days.json').write_text(json.dumps(days, ensure_ascii=False, separators=(',', ':')))
    manifest = {
        'source': 'Hong Kong Observatory official Gregorian-Lunar conversion PDFs, with explicitly recorded official TXT fallback',
        'retrievedAtUTC': dt.datetime.now(dt.timezone.utc).isoformat(),
        'pdftotextVersion': subprocess.run(['pdftotext', '-v'], capture_output=True, text=True).stderr.splitlines()[0],
        'range': [args.start, args.end], 'filesRequested': len(records),
        'filesParsed': sum(record['status'] == 'parsed' for record, _ in records),
        'pdfFilesParsed': sum(record.get('extraction') == 'pdf-bounding-boxes' for record, _ in records),
        'officialTextFallbackFiles': sum(record.get('extraction') == 'official-text-fallback' for record, _ in records),
        'daysExtracted': len(days), 'fullLunarDatesEstablished': sum(day['fullDateEstablished'] for day in days),
        'incompleteDateFields': [day for day in days if not day['fullDateEstablished']],
        'sequenceErrors': sequence_errors,
        'files': [record for record, _ in records],
    }
    (HERE / 'hko-daily-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in manifest.items() if k not in ['files', 'incompleteDateFields']}, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
