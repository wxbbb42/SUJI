/**
 * AI 文本富文本渲染入口
 * 后续 Task 会在这里接入 preprocessYiji、YiJiCard、ClassicalQuote、MingPanBadge
 */
import React from 'react';
import { Text } from 'react-native';
import Markdown from 'react-native-markdown-display';
import { richStyles } from './richStyles';
import { preprocessYiji } from './customRules/preprocessYiji';
import { YiJiCard, splitYiji } from './customRules/YiJiCard';
import { ClassicalQuote } from './customRules/ClassicalQuote';

function extractText(node: any): string {
  if (!node) return '';
  if (typeof node.content === 'string') return node.content;
  if (Array.isArray(node.children)) {
    return node.children.map(extractText).join('');
  }
  return '';
}

type Props = { content: string };

export function RichContent({ content }: Props) {
  const processed = preprocessYiji(content);

  return (
    <Markdown
      style={richStyles}
      rules={{
        blockquote: (node: any, children: any) => {
          const raw = extractText(node);
          return <ClassicalQuote key={node.key} rawText={raw} />;
        },
        fence: (node: any) => {
          const lang = node.sourceInfo || node.info || '';
          if (lang === 'yiji') {
            const text: string = node.content || '';
            return <YiJiCard key={node.key} yi={parseYi(text)} ji={parseJi(text)} />;
          }
          // 非 yiji fence：用普通 Text 降级渲染（避免 null 返回）
          return (
            <Text key={node.key} style={richStyles.code_inline}>{node.content}</Text>
          );
        },
      }}
    >
      {processed}
    </Markdown>
  );
}

function parseYi(body: string): string[] {
  const m = body.match(/yi:\s*(.+)/);
  return m ? splitYiji(m[1]) : [];
}

function parseJi(body: string): string[] {
  const m = body.match(/ji:\s*(.+)/);
  return m ? splitYiji(m[1]) : [];
}
