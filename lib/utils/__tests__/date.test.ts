import { dayOfYear } from '../date';

describe('dayOfYear', () => {
  it('returns 1 for Jan 1', () => {
    expect(dayOfYear(new Date(2026, 0, 1))).toBe(1);
  });

  it('returns 32 for Feb 1', () => {
    expect(dayOfYear(new Date(2026, 1, 1))).toBe(32);
  });

  it('returns 365 for Dec 31 non-leap year', () => {
    expect(dayOfYear(new Date(2026, 11, 31))).toBe(365);
  });

  it('returns 366 for Dec 31 leap year', () => {
    expect(dayOfYear(new Date(2024, 11, 31))).toBe(366);
  });
});
