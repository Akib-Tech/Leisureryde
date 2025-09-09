// lib/api.ts
import axios from "axios";

const API_URL = process.env.EXPO_PUBLIC_API_URL;

type RequestOtpPayload = { phone: string };
type VerifyOtpPayload = { phone: string; code: string };

export type AuthResponse = {
  token: string;            // JWT/opaque
  isNewUser: boolean;
  hasPin: boolean;
};

const http = API_URL
  ? axios.create({ baseURL: API_URL, timeout: 10000 })
  : null;

// --- Mock layer (no server needed) ---
const mockDB: Record<string, { code: string; hasPin: boolean }> = {};
const wait = (ms: number) => new Promise(r => setTimeout(r, ms));

async function mockRequestOtp({ phone }: RequestOtpPayload) {
  const code = "123456";
  mockDB[phone] = mockDB[phone] ?? { code, hasPin: false };
  mockDB[phone].code = code;
  await wait(600);
  console.log("[mock] OTP for", phone, "=", code);
  return { ok: true };
}

async function mockVerifyOtp({ phone, code }: VerifyOtpPayload): Promise<AuthResponse> {
  await wait(600);
  if (!mockDB[phone] || mockDB[phone].code !== code) {
    throw new Error("Invalid code");
  }
  const hasPin = mockDB[phone].hasPin;
  return { token: "mock-token-" + phone, isNewUser: !hasPin, hasPin };
}

async function mockSetPin(phone: string) {
  await wait(300);
  if (mockDB[phone]) mockDB[phone].hasPin = true;
}

// --- Real API (if API_URL set) ---
export const api = {
  async requestOtp(payload: RequestOtpPayload) {
    if (!http) return mockRequestOtp(payload);
    await http.post("/auth/request-otp", payload);
    return { ok: true };
  },
  async verifyOtp(payload: VerifyOtpPayload): Promise<AuthResponse> {
    if (!http) return mockVerifyOtp(payload);
    const { data } = await http.post("/auth/verify-otp", payload);
    return data;
  },
  async setPin(token: string, pin: string) {
    if (!http) {
      // derive phone from token in mock
      const phone = token.replace("mock-token-", "");
      return mockSetPin(phone);
    }
    await http.post(
      "/auth/set-pin",
      { pin },
      { headers: { Authorization: `Bearer ${token}` } }
    );
  }
};
