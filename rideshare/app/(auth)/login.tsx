// app/(auth)/login.tsx
import { View, Text, StyleSheet, Button, Alert } from "react-native";
import { useForm, Controller } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import FormTextInput from "../../components/FormTextInput";
import { useAuth } from "../../lib/auth-store";
import { colors } from "../../lib/theme";
import { router } from "expo-router";

const schema = z.object({ phone: z.string().min(10, "Enter a valid phone number") });

export default function Login() {
  const requestOtp = useAuth(s => s.requestOtp);
  const loading = useAuth(s => s.loading);

  const { control, handleSubmit, formState: { errors } } = useForm<{ phone: string }>({
    resolver: zodResolver(schema),
    defaultValues: { phone: "" }
  });

  const onSubmit = async ({ phone }: { phone: string }) => {
    try {
      await requestOtp(phone.trim());
      router.push("/(auth)/verify-otp");
    } catch (e: any) {
      Alert.alert("Error", e?.message ?? "Failed to request OTP");
    }
  };

  return (
    <View style={s.container}>
      <Text style={s.title}>Sign in</Text>
      <Controller
        name="phone"
        control={control}
        render={({ field: { onChange, value } }) => (
          <FormTextInput
            label="Phone number"
            keyboardType="phone-pad"
            value={value}
            onChangeText={onChange}
            placeholder="+2348012345678"
            error={errors.phone?.message}
          />
        )}
      />
      <Button title={loading ? "Sending..." : "Send OTP"} onPress={handleSubmit(onSubmit)} />
    </View>
  );
}
const s = StyleSheet.create({
  container: { flex: 1, padding: 24, backgroundColor: colors.lightBg },
  title: { fontSize: 24, fontWeight: "700", marginBottom: 16, color: colors.textOnLight }
});
