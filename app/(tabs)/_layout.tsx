import React from 'react';
import { StyleSheet, Platform } from 'react-native';
import { Tabs } from 'expo-router';
import { Colors, Space, Type, Size } from '@/lib/design/tokens';
import { useColorScheme } from '@/components/useColorScheme';
import { useClientOnlyValue } from '@/components/useClientOnlyValue';

/**
 * 岁吉 Tab 导航
 *
 * iOS 原生风格：毛玻璃 tab bar + SF Pro 文字图标
 * 四个字：历 · 问 · 静 · 我
 */

export default function TabLayout() {
  const colorScheme = useColorScheme();
  const dark = colorScheme === 'dark';

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors.vermilion,
        tabBarInactiveTintColor: Colors.inkHint,
        tabBarStyle: {
          backgroundColor: dark ? '#1A1410' : Colors.surface,
          borderTopWidth: StyleSheet.hairlineWidth,
          borderTopColor: Colors.borderLight,
          height: Platform.OS === 'ios' ? Size.tabBarHeight : 64,
          paddingTop: Space.sm,
          paddingBottom: Platform.OS === 'ios' ? 28 : 8,
        },
        tabBarLabelStyle: {
          ...Type.label,
          fontSize: 10,
          letterSpacing: 1,
          marginTop: 2,
        },
        tabBarIconStyle: {
          marginBottom: -2,
        },
        headerStyle: {
          backgroundColor: dark ? '#1A1410' : Colors.bg,
          elevation: 0,
          shadowOpacity: 0,
          borderBottomWidth: 0,
        },
        headerTitleStyle: {
          fontFamily: 'Georgia',
          color: dark ? Colors.surface : Colors.ink,
          fontSize: 17,
          fontWeight: '400',
          letterSpacing: 2,
        },
        headerShown: useClientOnlyValue(false, true),
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: '日历',
          tabBarIcon: ({ color }) => (
            <TabChar char="历" color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="insight"
        options={{
          title: '问道',
          tabBarIcon: ({ color }) => (
            <TabChar char="问" color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="ambiance"
        options={{
          title: '静心',
          tabBarIcon: ({ color }) => (
            <TabChar char="静" color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: '我的',
          tabBarIcon: ({ color }) => (
            <TabChar char="我" color={color} />
          ),
        }}
      />
    </Tabs>
  );
}

function TabChar({ char, color }: { char: string; color: string }) {
  return (
    <React.Fragment>
      {/* 用 Text 而不是 Icon，保持中文文化感 */}
      {React.createElement(
        require('react-native').Text,
        { style: [styles.tabChar, { color }] },
        char,
      )}
    </React.Fragment>
  );
}

const styles = StyleSheet.create({
  tabChar: {
    fontFamily: 'Georgia',
    fontSize: 22,
    fontWeight: '400',
  },
});
