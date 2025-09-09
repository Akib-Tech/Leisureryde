import { View, Text, Button, StyleSheet } from "react-native"
import { useRouter } from "expo-router"
import { useAuth } from "../lib/auth-store"
import { colors } from "../lib/theme"
import { useEffect } from "react"

export default function Home() {
  const token = useAuth((s) => s.token)
  const signOut = useAuth((s) => s.signOut)
  const router = useRouter()

  useEffect(() => {
    if (!token) router.replace("/(auth)/welcome")
  }, [token, router])

  if (!token) return null

  return 
}

const s = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.lightBg,
  },
  text: { fontSize: 18, marginBottom: 16, color: colors.textOnLight },
})
