/**
 * BirthInput — 生辰输入组件（重设计版）
 * 12宫格时辰点选 · 文字性别切换 · 文字提交按钮
 */
import React, { useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';

const SHICHEN = [
  { label: '子', range: '23–01', hour: 0 },
  { label: '丑', range: '01–03', hour: 2 },
  { label: '寅', range: '03–05', hour: 4 },
  { label: '卯', range: '05–07', hour: 6 },
  { label: '辰', range: '07–09', hour: 8 },
  { label: '巳', range: '09–11', hour: 10 },
  { label: '午', range: '11–13', hour: 12 },
  { label: '未', range: '13–15', hour: 14 },
  { label: '申', range: '15–17', hour: 16 },
  { label: '酉', range: '17–19', hour: 18 },
  { label: '戌', range: '19–21', hour: 20 },
  { label: '亥', range: '21–23', hour: 22 },
];

const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

// ── 色彩系统 ───────────────────────────────────────────────────────────
const C = {
  bg:      '#F5EDE0',
  surface: '#FFFBF5',
  deep:    '#2C1810',
  mid:     '#6B5040',
  mute:    '#8B7355',
  faint:   '#B8A898',
  brand:   '#8B4513',
};

interface BirthInputProps {
  onSubmit: (date: Date, gender: '男' | '女') => void;
}

export default function BirthInput({ onSubmit }: BirthInputProps) {
  const [year,       setYear]       = useState(1990);
  const [month,      setMonth]      = useState(6);
  const [day,        setDay]        = useState(15);
  const [shichenIdx, setShichenIdx] = useState(4);   // 寅时默认
  const [gender,     setGender]     = useState<'男' | '女'>('男');
  const [error,      setError]      = useState('');

  const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

  const adjYear  = (d: number) => setYear(v => clamp(v + d, 1920, new Date().getFullYear()));
  const adjMonth = (d: number) =>
    setMonth(v => {
      const n = clamp(v + d, 1, 12);
      setDay(dd => clamp(dd, 1, DAYS_IN_MONTH[n - 1]));
      return n;
    });
  const adjDay = (d: number) => setDay(v => clamp(v + d, 1, DAYS_IN_MONTH[month - 1]));

  const handleSubmit = () => {
    setError('');
    try {
      const { hour } = SHICHEN[shichenIdx];
      onSubmit(new Date(year, month - 1, day, hour, 0, 0), gender);
    } catch {
      setError('日期有误，请重新检查');
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.heading}>生辰</Text>
      <Text style={styles.sub}>据此推算你的专属命盘</Text>

      {/* 年月日 */}
      <View style={styles.dateRow}>
        <SpinField label="年" value={`${year}`}    onDec={() => adjYear(-1)}  onInc={() => adjYear(1)} />
        <SpinField label="月" value={`${month}月`} onDec={() => adjMonth(-1)} onInc={() => adjMonth(1)} />
        <SpinField label="日" value={`${day}日`}   onDec={() => adjDay(-1)}   onInc={() => adjDay(1)} />
      </View>

      {/* 时辰 12 宫格 */}
      <Text style={styles.fieldLabel}>时辰</Text>
      <View style={styles.shichenGrid}>
        {SHICHEN.map((s, i) => (
          <Pressable
            key={s.label}
            style={[styles.shichenCell, shichenIdx === i && styles.shichenCellOn]}
            onPress={() => setShichenIdx(i)}
          >
            <Text style={[styles.shichenChi, shichenIdx === i && styles.shichenChiOn]}>
              {s.label}
            </Text>
            <Text style={[styles.shichenRange, shichenIdx === i && styles.shichenRangeOn]}>
              {s.range}
            </Text>
          </Pressable>
        ))}
      </View>

      {/* 性别 */}
      <Text style={[styles.fieldLabel, { marginTop: 24 }]}>性别</Text>
      <View style={styles.genderRow}>
        {(['男', '女'] as const).map(g => (
          <Pressable key={g} style={styles.genderOpt} onPress={() => setGender(g)}>
            <Text style={[styles.genderChi, gender === g && styles.genderChiOn]}>{g}</Text>
            {gender === g && <View style={styles.genderLine} />}
          </Pressable>
        ))}
      </View>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      {/* 文字提交 */}
      <Pressable style={styles.submit} onPress={handleSubmit}>
        <Text style={styles.submitText}>推算命盘</Text>
      </Pressable>
    </View>
  );
}

// ── SpinField ─────────────────────────────────────────────────────────
function SpinField({
  label, value, onDec, onInc,
}: { label: string; value: string; onDec: () => void; onInc: () => void }) {
  return (
    <View style={styles.spinField}>
      <Text style={styles.spinLabel}>{label}</Text>
      <Pressable onPress={onDec} hitSlop={10}>
        <Text style={styles.spinBtn}>−</Text>
      </Pressable>
      <Text style={styles.spinVal}>{value}</Text>
      <Pressable onPress={onInc} hitSlop={10}>
        <Text style={styles.spinBtn}>+</Text>
      </Pressable>
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    paddingVertical: 32,
    paddingHorizontal: 24,
  },
  heading: {
    fontSize: 32,
    color: C.deep,
    fontWeight: '200',
    letterSpacing: 12,
    marginBottom: 6,
  },
  sub: {
    fontSize: 13,
    color: C.faint,
    letterSpacing: 2,
    marginBottom: 32,
  },
  // 年月日
  dateRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 32,
  },
  spinField: {
    flex: 1,
    alignItems: 'center',
    gap: 8,
  },
  spinLabel: {
    fontSize: 11,
    color: C.faint,
    letterSpacing: 3,
  },
  spinBtn: {
    fontSize: 22,
    color: C.mute,
    lineHeight: 28,
    paddingHorizontal: 4,
  },
  spinVal: {
    fontSize: 18,
    color: C.deep,
    fontWeight: '300',
    letterSpacing: 1,
    minWidth: 56,
    textAlign: 'center',
  },
  // 时辰
  fieldLabel: {
    fontSize: 11,
    color: C.faint,
    letterSpacing: 3,
    marginBottom: 12,
  },
  shichenGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 4,
  },
  shichenCell: {
    width: '24%',
    paddingVertical: 10,
    alignItems: 'center',
    borderRadius: 4,
  },
  shichenCellOn: {
    backgroundColor: C.surface,
  },
  shichenChi: {
    fontSize: 17,
    color: C.mid,
    fontWeight: '300',
  },
  shichenChiOn: {
    color: C.brand,
    fontWeight: '500',
  },
  shichenRange: {
    fontSize: 9,
    color: C.faint,
    marginTop: 2,
    letterSpacing: 0.5,
  },
  shichenRangeOn: {
    color: C.mute,
  },
  // 性别
  genderRow: {
    flexDirection: 'row',
    gap: 32,
    marginBottom: 40,
  },
  genderOpt: {
    alignItems: 'center',
    paddingBottom: 4,
  },
  genderChi: {
    fontSize: 16,
    color: C.faint,
    letterSpacing: 4,
  },
  genderChiOn: {
    color: C.deep,
  },
  genderLine: {
    marginTop: 4,
    height: 1,
    width: '100%',
    backgroundColor: C.brand,
  },
  // 错误
  error: {
    fontSize: 13,
    color: '#C0392B',
    marginBottom: 16,
    letterSpacing: 1,
  },
  // 提交
  submit: {
    alignSelf: 'flex-start',
    paddingVertical: 4,
  },
  submitText: {
    fontSize: 15,
    color: C.brand,
    letterSpacing: 6,
    fontWeight: '400',
  },
});
