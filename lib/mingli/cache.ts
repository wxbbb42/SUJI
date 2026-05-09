import type { MingPan } from '@/lib/bazi/types';
import type { ZiweiPan } from '@/lib/ziwei/types';

const MINGPAN_SCHEMA_VERSION = 1;
const ZIWEI_SCHEMA_VERSION = 1;

interface CacheEnvelope<T> {
  schemaVersion: number;
  kind: 'mingPan' | 'ziweiPan';
  data: T;
}

export interface CacheReadResult<T> {
  value: T | null;
  migrated: boolean;
}

function parseCache(raw: string | null): unknown {
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function unwrapEnvelope<T>(
  raw: unknown,
  kind: CacheEnvelope<T>['kind'],
  schemaVersion: number,
): { data: unknown; migrated: boolean } {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { data: null, migrated: false };
  }
  const record = raw as Partial<CacheEnvelope<T>>;
  if (record.kind === kind && record.schemaVersion === schemaVersion && record.data) {
    return { data: record.data, migrated: false };
  }
  return { data: raw, migrated: true };
}

function reviveDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (typeof value !== 'string') return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function serializeMingPanCache(mingPan: MingPan): string {
  const envelope: CacheEnvelope<MingPan> = {
    schemaVersion: MINGPAN_SCHEMA_VERSION,
    kind: 'mingPan',
    data: mingPan,
  };
  return JSON.stringify(envelope);
}

export function deserializeMingPanCache(raw: string | null): CacheReadResult<MingPan> {
  const parsed = parseCache(raw);
  const { data, migrated } = unwrapEnvelope<MingPan>(parsed, 'mingPan', MINGPAN_SCHEMA_VERSION);
  if (!data || typeof data !== 'object' || Array.isArray(data)) return { value: null, migrated: false };
  const pan = data as MingPan;
  const birthDateTime = reviveDate((pan as unknown as { birthDateTime?: unknown }).birthDateTime);
  if (!birthDateTime || !pan.siZhu || !pan.riZhu || !pan.wuXingStrength) {
    return { value: null, migrated };
  }
  pan.birthDateTime = birthDateTime;
  return { value: pan, migrated };
}

export function serializeZiweiPanCache(ziweiPan: ZiweiPan): string {
  const envelope: CacheEnvelope<ZiweiPan> = {
    schemaVersion: ZIWEI_SCHEMA_VERSION,
    kind: 'ziweiPan',
    data: ziweiPan,
  };
  return JSON.stringify(envelope);
}

export function deserializeZiweiPanCache(raw: string | null): CacheReadResult<ZiweiPan> {
  const parsed = parseCache(raw);
  const { data, migrated } = unwrapEnvelope<ZiweiPan>(parsed, 'ziweiPan', ZIWEI_SCHEMA_VERSION);
  if (!data || typeof data !== 'object' || Array.isArray(data)) return { value: null, migrated: false };
  const pan = data as ZiweiPan;
  const birthDateTime = reviveDate((pan as unknown as { birthDateTime?: unknown }).birthDateTime);
  const hasNormalizedPalaces =
    Array.isArray(pan.palaces) &&
    pan.palaces.length === 12 &&
    pan.palaces.every((p) => typeof p.name === 'string' && p.name.endsWith('宫'));
  if (!birthDateTime || !hasNormalizedPalaces) {
    return { value: null, migrated: true };
  }
  pan.birthDateTime = birthDateTime;
  return { value: pan, migrated };
}

