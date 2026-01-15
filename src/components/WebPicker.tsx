import React from 'react';
import {Platform} from 'react-native';
import {Picker} from '@react-native-picker/picker';
import {View, StyleSheet} from 'react-native';

interface WebPickerProps {
  selectedValue: string | null;
  onValueChange: (value: string) => void;
  children: React.ReactNode;
  style?: any;
}

const WebPicker: React.FC<WebPickerProps> & {
  Item: typeof Picker.Item;
} = ({
  selectedValue,
  onValueChange,
  children,
  style,
}) => {
  const toOptionString = (v: any): string => {
    if (v === null || v === undefined) return '';
    if (typeof v === 'string') return v;
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
    // common case: objects like { name }
    if (typeof v === 'object' && (v as any).name) return String((v as any).name);
    return String(v);
  };

  if (Platform.OS === 'web') {
    // Web için native HTML select kullan
    return (
      <View style={[styles.container, style]}>
        <select
          value={selectedValue || ''}
          onChange={(e) => onValueChange(e.target.value)}
          style={styles.select as any}>
          {React.Children.map(children, (child, idx) => {
            if (React.isValidElement(child) && child.props.value !== undefined) {
              const optionValue = toOptionString(child.props.value);
              const optionLabel = toOptionString(child.props.label);
              return (
                <option key={`${optionValue}-${idx}`} value={optionValue}>
                  {optionLabel}
                </option>
              );
            }
            return null;
          })}
        </select>
      </View>
    );
  }

  // Native için normal Picker
  return (
    <Picker
      selectedValue={selectedValue}
      onValueChange={onValueChange}
      style={style}>
      {children}
    </Picker>
  );
};

WebPicker.Item = Picker.Item;

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  select: {
    width: '100%',
    padding: 8,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#BDBDBD',
    borderRadius: 8,
    backgroundColor: '#fff',
  },
});

export default WebPicker;

