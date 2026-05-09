import { getShichenIndexForDate } from '../BirthInput';

describe('getShichenIndexForDate', () => {
  it('keeps 子时 at index 0 instead of falling back to 辰时', () => {
    expect(getShichenIndexForDate(new Date(2026, 0, 1, 0, 30))).toBe(0);
    expect(getShichenIndexForDate(new Date(2026, 0, 1, 23, 30))).toBe(0);
  });

  it('maps ordinary hours to the expected two-hour slot', () => {
    expect(getShichenIndexForDate(new Date(2026, 0, 1, 8, 0))).toBe(4);
    expect(getShichenIndexForDate(new Date(2026, 0, 1, 14, 0))).toBe(7);
  });
});

