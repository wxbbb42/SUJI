import { StyleSheet, View, Text, TextInput, ScrollView, Pressable } from 'react-native';
import { useState } from 'react';

export default function InsightScreen() {
  const [message, setMessage] = useState('');

  return (
    <View style={styles.container}>
      <ScrollView style={styles.chatArea} contentContainerStyle={styles.chatContent}>
        {/* AI 欢迎消息 */}
        <View style={styles.aiBubble}>
          <Text style={styles.aiName}>岁吉</Text>
          <Text style={styles.aiText}>
            今日巳火当令，适合内观与梳理。{'\n\n'}
            有什么想聊的？可以跟我说说你现在的心情，或者问问关于你自己的事。
          </Text>
        </View>
      </ScrollView>

      <View style={styles.inputArea}>
        <TextInput
          style={styles.input}
          placeholder="说说你的心情..."
          placeholderTextColor="#B8A898"
          value={message}
          onChangeText={setMessage}
          multiline
        />
        <Pressable style={styles.sendButton}>
          <Text style={styles.sendText}>→</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F0E8',
  },
  chatArea: {
    flex: 1,
  },
  chatContent: {
    padding: 20,
    paddingBottom: 40,
  },
  aiBubble: {
    backgroundColor: '#FFFDF8',
    borderRadius: 16,
    borderTopLeftRadius: 4,
    padding: 16,
    maxWidth: '85%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  aiName: {
    fontSize: 12,
    color: '#8B4513',
    fontWeight: '600',
    marginBottom: 6,
    letterSpacing: 2,
  },
  aiText: {
    fontSize: 15,
    color: '#2C1810',
    lineHeight: 24,
    letterSpacing: 0.5,
  },
  inputArea: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    padding: 16,
    paddingBottom: 34,
    backgroundColor: '#FFFDF8',
    borderTopWidth: 0.5,
    borderTopColor: '#E5DDD0',
  },
  input: {
    flex: 1,
    backgroundColor: '#F5F0E8',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 10,
    fontSize: 15,
    color: '#2C1810',
    maxHeight: 100,
  },
  sendButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#8B4513',
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 8,
  },
  sendText: {
    color: '#FFFDF8',
    fontSize: 18,
    fontWeight: '600',
  },
});
