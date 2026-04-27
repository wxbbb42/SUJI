import { parseAIResponse, CALIBRATION_SYSTEM_PROMPT } from '../CalibrationAI';

describe('parseAIResponse', () => {
  it('parses well-formed JSON', () => {
    const r = parseAIResponse('{"lastClassification":"yes","question":"你今年呢？"}', '原模板');
    expect(r.lastClassification).toBe('yes');
    expect(r.question).toBe('你今年呢？');
  });

  it('falls back to template raw when JSON invalid', () => {
    const r = parseAIResponse('not json', '原模板');
    expect(r.lastClassification).toBe('uncertain');
    expect(r.question).toBe('原模板');
  });

  it('falls back when classification is unknown enum', () => {
    const r = parseAIResponse('{"lastClassification":"maybe","question":"q"}', '原');
    expect(r.lastClassification).toBe('uncertain');
    expect(r.question).toBe('q');
  });

  it('treats null lastClassification as undefined (first round)', () => {
    const r = parseAIResponse('{"lastClassification":null,"question":"首题？"}', '首题');
    expect(r.lastClassification).toBeUndefined();
    expect(r.question).toBe('首题？');
  });
});

describe('CALIBRATION_SYSTEM_PROMPT', () => {
  it('contains required keywords', () => {
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('校准');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('JSON');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('lastClassification');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('question');
  });
});
