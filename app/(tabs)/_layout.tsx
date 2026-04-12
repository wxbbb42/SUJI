import React from 'react';
import { Text, StyleSheet } from 'react-native';
import { Tabs } from 'expo-router';
import { Colors } from '@/lib/design/tokens';
import { useColorScheme } from '@/components/useColorScheme';
import { useClientOnlyValue } from '@/components/useClientOnlyValue';

/**
 * 岁吉 Tab 导航
 * 
 * 用中文字代替图标——文字即界面
 * 四个字：历 · 问 · 静 · 我
 */

function TabLabel({ label, color }: { label: string; color: string }) {
  return <Text style={[styles.tabChar, { color }]}>{label}</Text>;
}

export default function TabLayout() {
  const colorScheme = useColorScheme();
  const dark = colorScheme === 'dark';

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors.brand,
        tabBarInactiveTintColor: Colors.inkTertiary,
        tabBarStyle: {
          backgroundColor: dark ? '#1A1410' : Colors.bg,
          borderTopWidth: 0,
          elevation: 0,
          height: 64,
          paddingTop: 8,
        },
        tabBarLabelStyle: { display: 'none' },
        headerStyle: {
          backgroundColor: dark ? '#1A1410' : Colors.bg,
          elevation: 0,
          shadowOpacity: 0,
        },
        headerTitleStyle: {
          color: dark ? Colors.surface : Colors.ink,
          fontSize: 17,
          fontWeight: '500',
          letterSpacing: 3,
        },
        headerShown: useClientOnlyValue(false, true),
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: '日历',
          tabBarIcon: ({ color }) => <TabLabel label="历" color={color} />,
        }}
      />
      <Tabs.Screen
        name="insight"
        options={{
          title: '问道',
          tabBarIcon: ({ color }) => <TabLabel label="问" color={color} />,
        }}
      />
      <Tabs.Screen
        name="ambiance"
        options={{
          title: '静心',
          tabBarIcon: ({ color }) => <TabLabel label="静" color={color} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: '我的',
          tabBarIcon: ({ color }) => <TabLabel label="我" color={color} />,
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabChar: {
    fontSize: 20,
    fontWeight: '300',
    letterSpacing: 0,
  },
});
