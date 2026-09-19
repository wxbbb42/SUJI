import type { ParameterSchema, ToolDefinition } from './types';

type Schema = ParameterSchema & {
  properties?: Record<string, Schema>;
  required?: string[];
  additionalProperties?: boolean;
};

/** The same bounded contract is enforced before Swift calls and at the local bridge. */
export function validateToolArguments(definition: ToolDefinition, input: unknown): asserts input is Record<string, unknown> {
  validate(input, definition.function.parameters as Schema, 'arguments');
  const args = input as Record<string, unknown>;
  if (typeof args.question === 'string' && !args.question.trim()) throw new Error('问题不能为空');
  if (definition.function.name !== 'get_timing') return;
  if (args.yearRange !== undefined) {
    const range = args.yearRange;
    if (args.scope !== 'liunian' || !Array.isArray(range) || range.length !== 2 ||
        !range.every(year => Number.isInteger(year) && year >= 1901 && year <= 2100) ||
        range[0] > range[1] || range[1] - range[0] > 20) {
      throw new Error('流年区间须为1901–2100内由早到晚的两个整数年份，最多跨20年');
    }
  }
  if (args.year !== undefined && (args.scope !== 'liuyue' || !Number.isInteger(args.year) ||
      (args.year as number) < 1901 || (args.year as number) > 2100)) {
    throw new Error('流月年份须为1901–2100内的整数，且仅用于liuyue');
  }
}

function validate(value: unknown, schema: Schema, path: string): void {
  const object = value !== null && typeof value === 'object' && !Array.isArray(value);
  const matches = schema.type === 'object' ? object
    : schema.type === 'array' ? Array.isArray(value)
    : schema.type === 'integer' ? Number.isInteger(value)
    : schema.type === 'number' ? typeof value === 'number' && Number.isFinite(value)
    : typeof value === schema.type;
  if (!matches) throw new Error(`${path}应为${schema.type}`);
  if (schema.enum && !schema.enum.includes(value as string)) throw new Error(`${path}不在允许值中`);
  if (typeof value === 'number') {
    if (!Number.isFinite(value) || (schema.minimum !== undefined && value < schema.minimum) ||
        (schema.maximum !== undefined && value > schema.maximum)) throw new Error(`${path}超出范围`);
  }
  if (typeof value === 'string') {
    const length = Array.from(value).length;
    if ((schema.minLength !== undefined && length < schema.minLength) ||
        (schema.maxLength !== undefined && length > schema.maxLength)) throw new Error(`${path}文字长度超出范围`);
  }
  if (Array.isArray(value)) {
    if ((schema.minItems !== undefined && value.length < schema.minItems) ||
        (schema.maxItems !== undefined && value.length > schema.maxItems)) throw new Error(`${path}项目数超出范围`);
    if (schema.items) value.forEach((item, index) => validate(item, schema.items as Schema, `${path}[${index}]`));
  }
  if (object) {
    const record = value as Record<string, unknown>;
    for (const required of schema.required ?? []) {
      if (record[required] === undefined || record[required] === null) throw new Error(`缺少必填参数${path}.${required}`);
    }
    for (const [key, item] of Object.entries(record)) {
      const child = schema.properties?.[key];
      if (child) validate(item, child, `${path}.${key}`);
      else if (schema.additionalProperties === false) throw new Error(`不支持的参数${path}.${key}`);
    }
  }
}
