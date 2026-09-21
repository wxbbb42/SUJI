// Isolated engine realm uses Beijing civil time. UI calendar day arrives explicitly.
// Never modify the app process timezone or the user's device settings.
(() => {
  const OriginalDate = Date;
  const offset = 8 * 60 * 60 * 1000;
  class BeijingDate extends OriginalDate {
    constructor(...args) {
      if (args.length === 0) super();
      else if (args.length === 1) super(args[0]);
      else super(OriginalDate.UTC(...args) - offset);
    }
    getTimezoneOffset() { return -480; }
    toLocaleDateString(locales, options) { return OriginalDate.prototype.toLocaleDateString.call(this, locales, { ...options, timeZone: 'Asia/Shanghai' }); }
  }
  for (const part of ['FullYear','Month','Date','Day','Hours','Minutes','Seconds','Milliseconds']) {
    BeijingDate.prototype[`get${part}`] = function() { return new OriginalDate(this.getTime()+offset)[`getUTC${part}`](); };
    if (part !== 'Day') BeijingDate.prototype[`set${part}`] = function(...values) {
      const shifted = new OriginalDate(this.getTime()+offset);
      const value = shifted[`setUTC${part}`](...values)-offset;
      this.setTime(value); return value;
    };
  }
  globalThis.Date = BeijingDate;
})();
