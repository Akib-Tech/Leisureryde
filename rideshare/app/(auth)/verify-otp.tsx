// app/(auth)/verify-otp.tsx
import { View, Text, StyleSheet, Button, Alert } from "react-native";
import OtpInput from "../../components/OtpInput";
import { useState } from "react";
import { useAuth } from "../../lib/auth-store";
import { colors } from "../../lib/theme";
import { router } from "expo-router";

export default function VerifyOtp() {
  const [code, setCode] = useState("");
  const verifyOtp = useAuth(s => s.verifyOtp);
  const loading = useAuth(s => s.loading);

  const onVerify = async () => {
    try {
      const resp = await verifyOtp(code);
      if (resp.isNewUser || !resp.hasPin) router.replace("/(auth)/create-pin");
      else router.replace("/");
    } catch (e: any) {
      Alert.alert("Invalid code", e?.message ?? "Please try again");
    }
  };

  return (
    <View style={s.container}>
      <Text style={s.title}>Enter OTP</Text>
      <OtpInput value={code} onChange={setCode} />
      <View style={{ height: 16 }} />
      <Button title={loading ? "Verifying..." : "Verify"} onPress={onVerify} />
      <Text style={s.hint}>Tip: in mock mode the code is <Text style={{fontWeight: "700"}}>123456</Text></Text>
    </View>
  );
}
const s = StyleSheet.create({
  container: { flex: 1, padding: 24, justifyContent: "center", backgroundColor: colors.lightBg },
  title: { fontSize: 24, fontWeight: "700", marginBottom: 16, color: colors.textOnLight },
  hint: { marginTop: 12, color: "#4B5563" }
});
