/**
 * AI 文本富文本渲染入口
 * 后续 Task 会在这里接入 preprocessYiji、YiJiCard、ClassicalQuote、MingPanBadge
 */
import React from 'react';
import Markdown from 'react-native-markdown-display';
import { richStyles } from './richStyles';

type Props = { content: string };

export function RichContent({ content }: Props) {
  return <Markdown style={richStyles}>{content}</Markdown>;
}
