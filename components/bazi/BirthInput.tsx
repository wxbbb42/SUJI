/**
 * BirthInput — 生辰输入组件（重设计版）
 * 12宫格时辰点选 · 文字性别切换 · 城市选择 · 文字提交按钮
 */
import React, { useState } from 'react';
import {
  View, Text, StyleSheet, Pressable, ScrollView, Modal,
} from 'react-native';
import { CITY_LONGITUDES } from '@/lib/bazi/TrueSolarTime';

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

// 城市列表（排序：直辖市优先，再按拼音）
const CITY_LIST = Object.keys(CITY_LONGITUDES);

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
  onSubmit: (date: Date, gender: '男' | '女', longitude: number) => void;
  initialDate?: Date;
  initialGender?: '男' | '女';
  initialCity?: string;
}

export default function BirthInput({
  onSubmit,
  initialDate,
  initialGender,
  initialCity,
}: BirthInputProps) {
  const initD = initialDate ?? new Date(1990, 5, 15, 4, 0, 0);

  const [year,       setYear]       = useState(initD.getFullYear());
  const [month,      setMonth]      = useState(initD.getMonth() + 1);
  const [day,        setDay]        = useState(initD.getDate());
  const [shichenIdx, setShichenIdx] = useState(() => {
    // 根据小时反推时辰
    const h = initD.getHours();
    return SHICHEN.findIndex(s => s.hour === Math.floor(h / 2) * 2) || 4;
  });
  const [gender,     setGender]     = useState<'男' | '女'>(initialGender ?? '男');
  const [city,       setCity]       = useState<string>(
    initialCity ?? (CITY_LIST[0] ?? '北京')
  );
  const [showCityPicker, setShowCityPicker] = useState(false);
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
      const longitude = CITY_LONGITUDES[city] ?? 116.4;
      onSubmit(new Date(year, month - 1, day, hour, 0, 0), gender, longitude);
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

      {/* 出生城市 */}
      <Text style={[styles.fieldLabel, { marginTop: 0 }]}>出生地</Text>
      <Pressable style={styles.cityButton} onPress={() => setShowCityPicker(true)}>
        <Text style={styles.cityValue}>{city}</Text>
        <Text style={styles.cityMeta}>
          {CITY_LONGITUDES[city] != null ? `东经 ${CITY_LONGITUDES[city]}°` : ''}
        </Text>
        <Text style={styles.cityChevron}>›</Text>
      </Pressable>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      {/* 文字提交 */}
      <Pressable style={styles.submit} onPress={handleSubmit}>
        <Text style={styles.submitText}>推算命盘</Text>
      </Pressable>

      {/* 城市选择器 Modal */}
      <Modal
        visible={showCityPicker}
        animationType="slide"
        transparent
        onRequestClose={() => setShowCityPicker(false)}
      >
        <Pressable style={styles.modalOverlay} onPress={() => setShowCityPicker(false)}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>选择出生地</Text>
            <ScrollView style={styles.cityList} showsVerticalScrollIndicator={false}>
              {CITY_LIST.map(c => (
                <Pressable
                  key={c}
                  style={[styles.cityItem, c === city && styles.cityItemOn]}
                  onPress={() => { setCity(c); setShowCityPicker(false); }}
                >
                  <Text style={[styles.cityItemText, c === city && styles.cityItemTextOn]}>
                    {c}
                  </Text>
                  <Text style={styles.cityItemLong}>
                    {CITY_LONGITUDES[c]}°
                  </Text>
                </Pressable>
              ))}
            </ScrollView>
          </View>
        </Pressable>
      </Modal>
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
    marginBottom: 32,
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
  // 城市
  cityButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    marginBottom: 32,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: C.faint + '60',
  },
  cityValue: {
    fontSize: 16,
    color: C.deep,
    fontWeight: '300',
    flex: 1,
  },
  cityMeta: {
    fontSize: 12,
    color: C.faint,
    marginRight: 8,
  },
  cityChevron: {
    fontSize: 18,
    color: C.faint,
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
  // 城市 Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(44,24,16,0.3)',
    justifyContent: 'flex-end',
  },
  modalSheet: {
    backgroundColor: C.surface,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    paddingTop: 20,
    paddingHorizontal: 24,
    maxHeight: '70%',
  },
  modalTitle: {
    fontSize: 15,
    color: C.deep,
    fontWeight: '500',
    letterSpacing: 3,
    marginBottom: 16,
  },
  cityList: {
    marginBottom: 32,
  },
  cityItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: C.faint + '40',
  },
  cityItemOn: {
    // 选中状态用左侧文字颜色区分，无多余装饰
  },
  cityItemText: {
    fontSize: 15,
    color: C.mid,
    flex: 1,
  },
  cityItemTextOn: {
    color: C.brand,
    fontWeight: '500',
  },
  cityItemLong: {
    fontSize: 12,
    color: C.faint,
  },
});
