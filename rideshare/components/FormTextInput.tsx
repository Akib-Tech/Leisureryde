import { View, TextInput, Text, StyleSheet } from "react-native";
import React from "react";
import { colors, radius, spacing } from "../lib/theme";

type Props = React.ComponentProps<typeof TextInput> & { label?: string; error?: string };

export default function FormTextInput({ label, error, style, ...rest }: Props) {
  return (
    <View style={{ marginBottom: spacing(1.5) }}>
      {label ? <Text style={s.label}>{label}</Text> : null}
      <TextInput
        placeholderTextColor="#9CA3AF"
        style={[s.input, style]}
        {...rest}
      />
      {!!error && <Text style={s.error}>{error}</Text>}
    </View>
  );
}

const s = StyleSheet.create({
  label: { color: colors.textOnLight, marginBottom: 6, fontWeight: "600" },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.lightBg,
    color: colors.textOnLight,
    borderRadius: radius,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16
  },
  error: { color: colors.danger, marginTop: 6 }
});
