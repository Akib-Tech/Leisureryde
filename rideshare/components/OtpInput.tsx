import { View, TextInput, StyleSheet } from "react-native";
import React, { useRef } from "react";
import { colors, radius } from "../lib/theme";

type Props = {
  length?: number;
  value: string;
  onChange: (v: string) => void;
};

export default function OtpInput({ length = 6, value, onChange }: Props) {
  const refs = useRef<TextInput[]>([]);

  return (
    <View style={s.row}>
      {Array.from({ length }).map((_, i) => (
        <TextInput
          key={i}
          ref={(r) => (refs.current[i] = r!)}
          keyboardType="number-pad"
          maxLength={1}
          value={value[i] ?? ""}
          onChangeText={(t) => {
            const chars = value.split("");
            chars[i] = t.replace(/[^0-9]/g, "");
            const next = chars.join("").slice(0, length);
            onChange(next);
            if (t && i < length - 1) refs.current[i + 1]?.focus();
          }}
          style={s.cell}
          placeholder="-"
          placeholderTextColor="#9CA3AF"
        />
      ))}
    </View>
  );
}

const s = StyleSheet.create({
  row: { flexDirection: "row", gap: 8, justifyContent: "center" },
  cell: {
    width: 46, height: 56,
    borderRadius: radius,
    borderWidth: 1, borderColor: colors.border,
    backgroundColor: colors.lightBg,
    textAlign: "center", fontSize: 20, color: colors.textOnLight
  }
});
