import { dispatch } from '../../../../bridge';
import { QimenEngine } from '../../../qimen/QimenEngine';

const now = '2004-05-29T04:00:00Z';
const args = { question: '核对本次降雨的取用', questionType: 'event', subject: 'unknown', event: '本次降雨', timeHorizon: 'near' };
const setup = (arguments_: unknown) => dispatch({ command: 'tool', name: 'setup_qimen', arguments: arguments_, now });

describe('explicit specialized Qimen selection through production dispatch', () => {
  it('exposes a bounded opt-in schema and preserves the exact focus and event', async () => {
    const definitions = await dispatch({ command: 'tools' });
    const definition = definitions.find((d: any) => d.function.name === 'setup_qimen');
    expect(definition.function.parameters.properties.selectionRequest).toMatchObject({
      type: 'object', additionalProperties: false, required: ['focus'],
    });
    const chart = (await setup({ ...args, selectionRequest: { focus: 'weather-rain' } })).result;
    expect(chart.specializedSelection).toMatchObject({ request: { focus: 'weather-rain' }, event: args.event, outcomeEstablished: false });
  });

  it('rejects invented focus, extra fields and malformed requests before calculating', async () => {
    for (const selectionRequest of [{}, { focus: 'weather-sun-guessed' }, { focus: 2 }, { focus: 'weather-rain', forceSuccess: true }, 'weather-rain']) {
      await expect(setup({ ...args, selectionRequest })).rejects.toThrow();
    }
  });

  it('updates the explicit selection on the original plate and clears it when absent', async () => {
    const original = (await setup({ ...args, selectionRequest: { focus: 'weather-rain' } })).result;
    const snapshot = JSON.stringify(original);
    const spy = jest.spyOn(QimenEngine.prototype, 'setup').mockImplementation(() => { throw new Error('must not recast'); });
    try {
      const revised = (await dispatch({ command: 'reassess-question', name: 'setup_qimen', sourceCallID: 'original', original,
        arguments: { ...args, event: '补充核对降雪', selectionRequest: { focus: 'weather-snow' } } })).result;
      expect(revised.specializedSelection).toMatchObject({ request: { focus: 'weather-snow' }, event: '补充核对降雪' });
      expect(revised.palaces).toEqual(original.palaces);
      expect(revised.setupTime).toEqual(original.setupTime);
      expect(JSON.stringify(original)).toEqual(snapshot);
      const cleared = (await dispatch({ command: 'reassess-question', name: 'setup_qimen', sourceCallID: 'original', original, arguments: args })).result;
      expect(cleared.specializedSelection).toBeUndefined();
      expect(cleared.ruleSources.some((s: any) => ['qimen-xdyy-weather-selection-v1', 'qimen-xdyy-dwelling-selection-v1'].includes(s.id))).toBe(false);
      expect(spy).not.toHaveBeenCalled();
    } finally { spy.mockRestore(); }
  });
});
