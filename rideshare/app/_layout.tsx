import { Stack } from "expo-router";
import { useEffect } from "react";
import { useAuth } from "../lib/auth-store";

export default function RootLayout() {
  const hydrate = useAuth(s => s.hydrate);
  useEffect(() => { hydrate(); }, []);
  return (
    <Stack screenOptions={{ headerShown: false }} />
  );
}
