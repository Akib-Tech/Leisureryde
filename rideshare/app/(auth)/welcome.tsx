// app/(auth)/welcome.tsx
import { View, Text, StyleSheet, Button } from "react-native";
import { Link } from "expo-router";
import { colors } from "../../lib/theme";

export default function Welcome() {
  return (
    <View style={s.container}>
      <Text style={s.title}>Welcome 👋</Text>
      <Text style={s.subtitle}>Sign in to request rides.</Text>
      <Link href="/(auth)/login" asChild>
        <Button title="Continue" />
      </Link>
    </View>
  );
}
const s = StyleSheet.create({
  container: { flex: 1, justifyContent: "center", padding: 24, backgroundColor: colors.lightBg },
  title: { fontSize: 28, fontWeight: "700", marginBottom: 8, color: colors.textOnLight },
  subtitle: { fontSize: 16, color: "#374151", marginBottom: 24 }
});
