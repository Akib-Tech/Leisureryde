// lib/auth-store.ts
import { create } from "zustand";
import * as SecureStore from "expo-secure-store";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { api, AuthResponse } from "./api";

const TOKEN_KEY = "auth.token";
const PHONE_KEY = "auth.phone";

type AuthState = {
  phone: string;
  token: string | null;
  loading: boolean;
  requestOtp: (phone: string) => Promise<void>;
  verifyOtp: (code: string) => Promise<AuthResponse>;
  setPin: (pin: string) => Promise<void>;
  signOut: () => Promise<void>;
  hydrate: () => Promise<void>;
};

async function saveToken(token: string) {
  try {
    await SecureStore.setItemAsync(TOKEN_KEY, token);
  } catch {
    await AsyncStorage.setItem(TOKEN_KEY, token);
  }
}
async function loadToken() {
  const secure = await SecureStore.getItemAsync(TOKEN_KEY);
  if (secure) return secure;
  return AsyncStorage.getItem(TOKEN_KEY);
}
async function clearToken() {
  try {
    await SecureStore.deleteItemAsync(TOKEN_KEY);
  } catch {}
  await AsyncStorage.removeItem(TOKEN_KEY);
}

export const useAuth = create<AuthState>((set, get) => ({
  phone: "",
  token: null,
  loading: false,

  hydrate: async () => {
    const [token, phone] = await Promise.all([loadToken(), AsyncStorage.getItem(PHONE_KEY)]);
    set({ token: token ?? null, phone: phone ?? "" });
  },

  requestOtp: async (phone) => {
    set({ loading: true });
    try {
      await api.requestOtp({ phone });
      await AsyncStorage.setItem(PHONE_KEY, phone);
      set({ phone });
    } finally {
      set({ loading: false });
    }
  },

  verifyOtp: async (code) => {
    set({ loading: true });
    try {
      const resp = await api.verifyOtp({ phone: get().phone, code });
      await saveToken(resp.token);
      set({ token: resp.token });
      return resp;
    } finally {
      set({ loading: false });
    }
  },

  setPin: async (pin) => {
    set({ loading: true });
    try {
      const token = get().token!;
      await api.setPin(token, pin);
    } finally {
      set({ loading: false });
    }
  },

  signOut: async () => {
    await clearToken();
    await AsyncStorage.multiRemove([PHONE_KEY]);
    set({ token: null, phone: "" });
  }
}));
