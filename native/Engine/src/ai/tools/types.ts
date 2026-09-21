import type { NatalAstronomy } from '../../astronomy/natal';
/**
 * AI tool-use 协议类型（OpenAI-compatible function calling）
 */

/** 工具定义（发给 LLM 的 schema） */
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: {
      type: 'object';
      properties: Record<string, ParameterSchema>;
      required?: string[];
      additionalProperties?: boolean;
    };
  };
}

export interface ParameterSchema {
  type: 'string' | 'number' | 'integer' | 'boolean' | 'array' | 'object';
  description?: string;
  enum?: string[];
  items?: ParameterSchema;
  minimum?: number;
  maximum?: number;
  minLength?: number;
  maxLength?: number;
  minItems?: number;
  maxItems?: number;
}

/** LLM 返回的工具调用请求 */
export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

/** 工具执行结果（送回 LLM） */
export interface ToolResult {
  tool_call_id: string;
  content: string;     // JSON.stringify 的执行结果（< 200 tokens 预算）
}

/** 工具执行函数签名 */
export type ToolHandler = (
  args: Record<string, unknown>,
  context: ToolContext,
) => Promise<unknown> | unknown;

/** 工具执行上下文（命盘等） */
export interface ToolContext {
  astronomy?: NatalAstronomy;
  mingPan: any;        // BaziEngine 输出（来自 mingPanCache）
  ziweiPan: any;       // ZiweiEngine 输出（来自 ziweiPanCache）
  now: Date;
}
