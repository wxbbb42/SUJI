import { dispatch } from '../../../../bridge';
import { QimenEngine } from '../../../qimen/QimenEngine';

const now='2004-05-29T04:00:00Z';
const args={question:'本人工作事项何时变化',questionType:'career',subject:'self',event:'工作事项',timeHorizon:'near'};
const timingRequest={focus:'employment',event:'本人工作事项的变化',timeUnit:'day',window:{end:'2004-06-10T00:00:00+08:00',maxCandidates:8}};
const setup=(arguments_:unknown)=>dispatch({command:'tool',name:'setup_qimen',arguments:arguments_,now});

describe('Qimen timing through actual tool dispatch',()=>{
  it('exposes bounded nested schema and returns the source chart horse window',async()=>{
    const definitions=await dispatch({command:'tools'});
    const definition=definitions.find((d:any)=>d.function.name==='setup_qimen');
    expect(definition.function.parameters.properties.timingRequest).toMatchObject({type:'object',additionalProperties:false,required:['focus','event']});
    const chart=(await setup({...args,timingRequest})).result;
    expect(chart.timing).toMatchObject({outcomeEstablished:false,assessmentStatus:'conditional-calendar-candidates',selection:{symbol:'开门',palaceId:2}});
    expect(chart.timing.dates[0]).toMatchObject({ganZhi:'甲寅',startsAt:'2004-06-03T15:00:00.000Z',triggerIds:['horse-clash']});
    expect(chart.ruleSources.filter((s:any)=>s.id==='qimen-xdyy-timing-v1')).toHaveLength(1);
  });
  it('rejects malformed nested values before accepting a cast request',async()=>{
    for(const change of [
      {...timingRequest,focus:'wealth'}, {...timingRequest,timeUnit:'near'}, {...timingRequest,event:''},
      {...timingRequest,window:{end:'2004-06-10T00:00:00Z',maxCandidates:0}},
      {...timingRequest,window:{end:'2004-06-10T00:00:00Z',includeCurrent:'yes'}},
      {...timingRequest,window:{end:'2004-06-10T00:00:00Z',recast:true}},
      {...timingRequest,object:{candidateId:'day-stem',objectPath:9}},
      {...timingRequest,window:{end:'2004-06-31T00:00:00Z'}},
    ])await expect(setup({...args,timingRequest:change})).rejects.toThrow();
  });
  it('reassesses timing from the preserved plate and removes stale timing without a replacement request',async()=>{
    const original=(await setup({...args,timingRequest})).result;
    const before=JSON.stringify(original);
    const setupSpy=jest.spyOn(QimenEngine.prototype,'setup').mockImplementation(()=>{throw new Error('recast forbidden');});
    try {
      const result=(await dispatch({command:'reassess-question',name:'setup_qimen',sourceCallID:'source-A',original,
        arguments:{...args,timingRequest:{...timingRequest,timeUnit:'hour',window:{end:'2004-05-31T00:00:00Z'}}}})).result;
      expect(result.timing.dates[0]).toMatchObject({unit:'hour',branch:'申',startsAt:'2004-05-29T07:00:00.000Z'});
      expect(result.setupTime).toBe(original.setupTime);expect(result.palaces).toEqual(original.palaces);
      expect(JSON.stringify(original)).toBe(before);expect(setupSpy).not.toHaveBeenCalled();
      const cleared=(await dispatch({command:'reassess-question',name:'setup_qimen',sourceCallID:'source-A',original,arguments:args})).result;
      expect(cleared.timing).toBeUndefined();
      expect(cleared.ruleSources.some((s:any)=>s.id==='qimen-xdyy-timing-v1')).toBe(false);
    }finally{setupSpy.mockRestore();}
  });
});
