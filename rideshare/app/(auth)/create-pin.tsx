// app/(auth)/create-pin.tsx
import { View, Text, StyleSheet, Button, Alert, TextInput } from "react-native";
import React, { useState } from "react";
import { colors, radius } from "../../lib/theme";
import { useAuth } from "../../lib/auth-store";
import { router } from "expo-router";

export default function CreatePin() {
  const [pin, setPin] = useState("");
  const [confirm, setConfirm] = useState("");
  const setPinApi = useAuth(s => s.setPin);
  const loading = useAuth(s => s.loading);

  const onSave = async () => {
    if (pin.length !== 4 || confirm.length !== 4) {
      Alert.alert("PIN must be 4 digits");
      return;
    }
    if (pin !== confirm) {
      Alert.alert("PINs do not match");
      return;
    }
    try {
      await setPinApi(pin);
      router.replace("/");
    } catch (e: any) {
      Alert.alert("Failed", e?.message ?? "Could not set PIN");
    }
  };

  return (
    <View style={s.container}>
      <Text style={s.title}>Create a 4-digit PIN</Text>
      <TextInput
        style={s.input}
        secureTextEntry
        keyboardType="number-pad"
        maxLength={4}
        value={pin}
        onChangeText={setPin}
        placeholder="••••"
        placeholderTextColor="#9CA3AF"
      />
      <TextInput
        style={s.input}
        secureTextEntry
        keyboardType="number-pad"
        maxLength={4}
        value={confirm}
        onChangeText={setConfirm}
        placeholder="••••"
        placeholderTextColor="#9CA3AF"
      />
      <Button title={loading ? "Saving..." : "Save PIN"} onPress={onSave} />
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1, padding: 24, justifyContent: "center", backgroundColor: colors.lightBg },
  title: { fontSize: 24, fontWeight: "700", marginBottom: 16, color: colors.textOnLight },
  input: {
    borderWidth: 1, borderColor: "#D1D5DB",
    backgroundColor: "#FFFFFF", color: "#111827",
    borderRadius: radius, paddingHorizontal: 14, paddingVertical: 12,
    fontSize: 18, marginBottom: 12, letterSpacing: 8, textAlign: "center"
  }
});
