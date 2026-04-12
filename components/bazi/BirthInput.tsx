/**
 * BirthInput — 生辰输入组件
 * 输入年月日 + 时辰（子时-亥时）+ 性别，提交后调用 BaziEngine.calculate()
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  Modal,
} from 'react-native';
// ── 时辰列表（地支 + 对应时刻） ────────────────────────────────────
const SHICHEN = [
  { label: '子时', range: '23:00–01:00', hour: 0 },
  { label: '丑时', range: '01:00–03:00', hour: 2 },
  { label: '寅时', range: '03:00–05:00', hour: 4 },
  { label: '卯时', range: '05:00–07:00', hour: 6 },
  { label: '辰时', range: '07:00–09:00', hour: 8 },
  { label: '巳时', range: '09:00–11:00', hour: 10 },
  { label: '午时', range: '11:00–13:00', hour: 12 },
  { label: '未时', range: '13:00–15:00', hour: 14 },
  { label: '申时', range: '15:00–17:00', hour: 16 },
  { label: '酉时', range: '17:00–19:00', hour: 18 },
  { label: '戌时', range: '19:00–21:00', hour: 20 },
  { label: '亥时', range: '21:00–23:00', hour: 22 },
];

const CURRENT_YEAR = new Date().getFullYear();
const MIN_YEAR = 1920;
const MAX_YEAR = CURRENT_YEAR;

// ── 每月最大天数（不含闰年判断，超出的日期引擎内部会 clamp） ────────
const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

interface BirthInputProps {
  onSubmit: (date: Date, gender: '男' | '女') => void;
}

export default function BirthInput({ onSubmit }: BirthInputProps) {
  const [year, setYear]       = useState(1990);
  const [month, setMonth]     = useState(1);
  const [day, setDay]         = useState(1);
  const [shichenIdx, setShichenIdx] = useState(4); // 寅时默认
  const [gender, setGender]   = useState<'男' | '女'>('男');
  const [shichenModal, setShichenModal] = useState(false);
  const [error, setError]     = useState('');

  // ── 数值调节辅助 ──────────────────────────────────────────────────
  const clamp = (v: number, min: number, max: number) =>
    Math.max(min, Math.min(max, v));

  const adjustYear  = (d: number) => setYear(v => clamp(v + d, MIN_YEAR, MAX_YEAR));
  const adjustMonth = (d: number) => {
    setMonth(v => {
      const next = clamp(v + d, 1, 12);
      setDay(dd => clamp(dd, 1, DAYS_IN_MONTH[next - 1]));
      return next;
    });
  };
  const adjustDay   = (d: number) =>
    setDay(v => clamp(v + d, 1, DAYS_IN_MONTH[month - 1]));

  // ── 提交 ──────────────────────────────────────────────────────────
  const handleSubmit = () => {
    setError('');
    try {
      const { hour } = SHICHEN[shichenIdx];
      const birthDate = new Date(year, month - 1, day, hour, 0, 0);
      onSubmit(birthDate, gender);
    } catch (e) {
      setError('日期格式有误，请重新检查');
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>输入生辰</Text>
      <Text style={styles.subtitle}>解锁专属命盘与五行分析</Text>

      {/* 年 */}
      <View style={styles.field}>
        <Text style={styles.fieldLabel}>年</Text>
        <View style={styles.stepper}>
          <Pressable style={styles.stepBtn} onPress={() => adjustYear(-1)}>
            <Text style={styles.stepBtnText}>－</Text>
          </Pressable>
          <Text style={styles.stepValue}>{year}</Text>
          <Pressable style={styles.stepBtn} onPress={() => adjustYear(1)}>
            <Text style={styles.stepBtnText}>＋</Text>
          </Pressable>
        </View>
      </View>

      {/* 月 */}
      <View style={styles.field}>
        <Text style={styles.fieldLabel}>月</Text>
        <View style={styles.stepper}>
          <Pressable style={styles.stepBtn} onPress={() => adjustMonth(-1)}>
            <Text style={styles.stepBtnText}>－</Text>
          </Pressable>
          <Text style={styles.stepValue}>{month} 月</Text>
          <Pressable style={styles.stepBtn} onPress={() => adjustMonth(1)}>
            <Text style={styles.stepBtnText}>＋</Text>
          </Pressable>
        </View>
      </View>

      {/* 日 */}
      <View style={styles.field}>
        <Text style={styles.fieldLabel}>日</Text>
        <View style={styles.stepper}>
          <Pressable style={styles.stepBtn} onPress={() => adjustDay(-1)}>
            <Text style={styles.stepBtnText}>－</Text>
          </Pressable>
          <Text style={styles.stepValue}>{day} 日</Text>
          <Pressable style={styles.stepBtn} onPress={() => adjustDay(1)}>
            <Text style={styles.stepBtnText}>＋</Text>
          </Pressable>
        </View>
      </View>

      {/* 时辰 */}
      <View style={styles.field}>
        <Text style={styles.fieldLabel}>时辰</Text>
        <Pressable style={styles.dropdown} onPress={() => setShichenModal(true)}>
          <Text style={styles.dropdownText}>
            {SHICHEN[shichenIdx].label}
          </Text>
          <Text style={styles.dropdownSub}>
            {SHICHEN[shichenIdx].range}
          </Text>
          <Text style={styles.dropdownArrow}>▾</Text>
        </Pressable>
      </View>

      {/* 性别 */}
      <View style={styles.field}>
        <Text style={styles.fieldLabel}>性别</Text>
        <View style={styles.genderRow}>
          {(['男', '女'] as const).map(g => (
            <Pressable
              key={g}
              style={[styles.genderBtn, gender === g && styles.genderBtnActive]}
              onPress={() => setGender(g)}
            >
              <Text style={[styles.genderBtnText, gender === g && styles.genderBtnTextActive]}>
                {g}
              </Text>
            </Pressable>
          ))}
        </View>
      </View>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      {/* 提交 */}
      <Pressable style={styles.submitBtn} onPress={handleSubmit}>
        <Text style={styles.submitText}>推算命盘</Text>
      </Pressable>

      {/* 时辰选择弹窗 */}
      <Modal
        visible={shichenModal}
        transparent
        animationType="fade"
        onRequestClose={() => setShichenModal(false)}
      >
        <Pressable style={styles.modalOverlay} onPress={() => setShichenModal(false)}>
          <View style={styles.modalBox}>
            <Text style={styles.modalTitle}>选择时辰</Text>
            <ScrollView>
              {SHICHEN.map((s, i) => (
                <Pressable
                  key={s.label}
                  style={[styles.shichenItem, shichenIdx === i && styles.shichenItemActive]}
                  onPress={() => {
                    setShichenIdx(i);
                    setShichenModal(false);
                  }}
                >
                  <Text style={[styles.shichenLabel, shichenIdx === i && styles.shichenLabelActive]}>
                    {s.label}
                  </Text>
                  <Text style={styles.shichenRange}>{s.range}</Text>
                </Pressable>
              ))}
            </ScrollView>
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFDF8',
    borderRadius: 16,
    padding: 24,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  title: {
    fontSize: 20,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 4,
    textAlign: 'center',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 13,
    color: '#B8A898',
    textAlign: 'center',
    letterSpacing: 1,
    marginBottom: 24,
  },
  field: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  fieldLabel: {
    width: 40,
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '500',
    letterSpacing: 1,
  },
  stepper: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F5F0E8',
    borderRadius: 10,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
    overflow: 'hidden',
  },
  stepBtn: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    backgroundColor: '#F5F0E8',
  },
  stepBtnText: {
    fontSize: 18,
    color: '#8B4513',
    lineHeight: 20,
  },
  stepValue: {
    flex: 1,
    textAlign: 'center',
    fontSize: 16,
    color: '#2C1810',
    fontWeight: '500',
    letterSpacing: 2,
  },
  dropdown: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F5F0E8',
    borderRadius: 10,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  dropdownText: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '500',
    letterSpacing: 2,
    marginRight: 8,
  },
  dropdownSub: {
    flex: 1,
    fontSize: 12,
    color: '#B8A898',
  },
  dropdownArrow: {
    fontSize: 14,
    color: '#8B7355',
  },
  genderRow: {
    flex: 1,
    flexDirection: 'row',
    gap: 12,
  },
  genderBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
    backgroundColor: '#F5F0E8',
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  genderBtnActive: {
    backgroundColor: '#8B4513',
    borderColor: '#8B4513',
  },
  genderBtnText: {
    fontSize: 15,
    color: '#8B7355',
    letterSpacing: 2,
    fontWeight: '500',
  },
  genderBtnTextActive: {
    color: '#FFFDF8',
  },
  error: {
    fontSize: 13,
    color: '#E53935',
    textAlign: 'center',
    marginBottom: 12,
  },
  submitBtn: {
    marginTop: 8,
    backgroundColor: '#8B4513',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  submitText: {
    fontSize: 16,
    color: '#FFFDF8',
    fontWeight: '600',
    letterSpacing: 4,
  },
  // Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(44,24,16,0.4)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalBox: {
    width: '80%',
    maxHeight: '70%',
    backgroundColor: '#FFFDF8',
    borderRadius: 16,
    padding: 20,
  },
  modalTitle: {
    fontSize: 17,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 3,
    textAlign: 'center',
    marginBottom: 16,
  },
  shichenItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 12,
    borderRadius: 8,
    marginBottom: 4,
  },
  shichenItemActive: {
    backgroundColor: '#F5F0E8',
  },
  shichenLabel: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '500',
    letterSpacing: 2,
    width: 60,
  },
  shichenLabelActive: {
    color: '#8B4513',
    fontWeight: '700',
  },
  shichenRange: {
    fontSize: 13,
    color: '#B8A898',
  },
});
