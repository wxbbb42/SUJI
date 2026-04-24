/**
 * Markdown 元素样式，全部使用 design tokens
 */
import { StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type } from '@/lib/design/tokens';

export const richStyles = StyleSheet.create({
  body: {
    ...Type.body,
    color: Colors.ink,
    lineHeight: 28,
  },
  paragraph: {
    marginTop: 0,
    marginBottom: Space.md,
  },
  heading1: {
    fontFamily: 'Georgia',
    fontSize: 28,
    fontWeight: '400',
    color: Colors.ink,
    marginTop: Space.lg,
    marginBottom: Space.md,
  },
  heading2: {
    fontFamily: 'Georgia',
    fontSize: 22,
    fontWeight: '500',
    color: Colors.ink,
    marginTop: Space.md,
    marginBottom: Space.sm,
  },
  heading3: {
    fontFamily: 'Georgia',
    fontSize: 18,
    fontWeight: '500',
    color: Colors.ink,
    marginTop: Space.md,
    marginBottom: Space.xs,
  },
  strong: {
    color: Colors.vermilion,
    fontWeight: '600',
  },
  em: {
    color: Colors.inkSecondary,
    fontStyle: 'italic',
  },
  bullet_list: {
    marginVertical: Space.sm,
  },
  ordered_list: {
    marginVertical: Space.sm,
  },
  list_item: {
    flexDirection: 'row',
    marginBottom: Space.xs,
  },
  bullet_list_icon: {
    color: Colors.vermilion,
    marginRight: Space.sm,
    fontSize: 16,
    lineHeight: 28,
  },
  blockquote: {
    backgroundColor: Colors.brandBg,
    borderLeftWidth: 2,
    borderLeftColor: Colors.vermilion,
    paddingHorizontal: Space.base,
    paddingVertical: Space.md,
    marginVertical: Space.md,
    borderRadius: Radius.xs,
  },
  hr: {
    backgroundColor: Colors.vermilion,
    height: 1,
    marginVertical: Space.md,
    opacity: 0.4,
  },
  code_inline: {
    backgroundColor: Colors.bgSecondary,
    fontFamily: 'Courier',
    paddingHorizontal: 4,
    borderRadius: 3,
  },
});
