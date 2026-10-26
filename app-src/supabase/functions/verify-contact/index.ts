// Verifies a new resident's email address and mobile number.
//
// The resident picks ONE way to confirm: channel "sms" (text message through Twilio) or channel "email" (Gmail/SMTP).
// action "options": { }                       - which ways are set up, and where a code would go (masked)
// action "send":    { channel }                - sends one code by that way
// action "check":   { channel, code }          - checks it
// Without a channel the old behaviour is kept (both codes, used by the older app): send, then check with emailCode + smsCode.
//
// action "send":  emails one 6-digit code and texts another to the numbers on the account.
// action "check": { emailCode, smsCode } - when both are right the account is marked verified
//                 (profiles.contact_verified_at). Until then the database shows the resident nothing.
//
// Secrets to set in Supabase (Edge Functions > Secrets). Never put them in the app or the website.
//   Email (SMTP, use port 465):  SMTP_HOST, SMTP_PORT (465), SMTP_USER, SMTP_PASS, SMTP_FROM
//   SMS, pick one:
//     SMS_PROVIDER=twilio      TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_FROM (a number)
//                              or TWILIO_MESSAGING_SERVICE_SID
//     SMS_PROVIDER=semaphore   SEMAPHORE_API_KEY, optional SEMAPHORE_SENDER
import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const CODE_MINUTES = 10;
const MAX_ATTEMPTS = 5;
const COOLDOWN_SECONDS = 60;
const MAX_SENDS_PER_HOUR = 5;

function newCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

async function hash(userId: string, channel: string, code: string): Promise<string> {
  const data = new TextEncoder().encode(`${userId}|${channel}|${code}`);
  const buf = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** "0917 123 4567", "+63 917 123 4567", "9171234567" -> "+639171234567" (null if not a PH mobile). */
function normalizePhone(raw: string): string | null {
  let d = String(raw ?? "").replace(/[^\d+]/g, "");
  if (d.startsWith("+")) d = d.slice(1);
  if (d.startsWith("63")) d = d.slice(2);
  else if (d.startsWith("0")) d = d.slice(1);
  return /^9\d{9}$/.test(d) ? `+63${d}` : null;
}

function maskEmail(e: string): string {
  const [u, d] = e.split("@");
  return `${u.slice(0, 2)}${"*".repeat(Math.max(1, u.length - 2))}@${d}`;
}
function maskPhone(p: string): string {
  return `${p.slice(0, 5)}${"*".repeat(Math.max(1, p.length - 8))}${p.slice(-3)}`;
}

function emailReady(): boolean {
  return !!(Deno.env.get("SMTP_HOST") && Deno.env.get("SMTP_USER") && Deno.env.get("SMTP_PASS"));
}
function smsProvider(): string {
  const p = (Deno.env.get("SMS_PROVIDER") ?? "").toLowerCase();
  if (p) return p;
  return Deno.env.get("TWILIO_ACCOUNT_SID") ? "twilio" : "";
}
function smsReady(): boolean {
  const p = smsProvider();
  if (p === "twilio") {
    return !!(Deno.env.get("TWILIO_ACCOUNT_SID") && Deno.env.get("TWILIO_AUTH_TOKEN") &&
      (Deno.env.get("TWILIO_FROM") || Deno.env.get("TWILIO_MESSAGING_SERVICE_SID")));
  }
  if (p === "semaphore") return !!Deno.env.get("SEMAPHORE_API_KEY");
  return false;
}

async function sendEmail(to: string, code: string) {
  const host = Deno.env.get("SMTP_HOST"), user = Deno.env.get("SMTP_USER"), pass = Deno.env.get("SMTP_PASS");
  if (!host || !user || !pass) throw new Error("Email sending is not set up yet. Please tell the administrator.");
  const port = Number(Deno.env.get("SMTP_PORT") ?? "465");
  const transport = nodemailer.createTransport({ host, port, secure: port === 465, auth: { user, pass } });
  await transport.sendMail({
    from: Deno.env.get("SMTP_FROM") ?? user,
    to,
    subject: "Your ResidentHub verification code",
    text: `Your ResidentHub verification code is ${code}.\n\nIt expires in ${CODE_MINUTES} minutes. Do not share it with anyone. ` +
      `If you did not expect this, ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px"><h2 style="color:#11263E">ResidentHub</h2>` +
      `<p>Your verification code is</p><p style="font-size:30px;letter-spacing:6px;font-weight:bold;color:#11263E">${code}</p>` +
      `<p style="color:#555">It expires in ${CODE_MINUTES} minutes. Do not share it with anyone. If you did not expect this, ignore this email.</p></div>`,
  });
}

async function sendSms(to: string, code: string) {
  const text = `ResidentHub: your verification code is ${code}. It expires in ${CODE_MINUTES} minutes. Do not share it.`;
  const provider = smsProvider();
  if (provider === "twilio") {
    const sid = Deno.env.get("TWILIO_ACCOUNT_SID"), token = Deno.env.get("TWILIO_AUTH_TOKEN");
    const from = Deno.env.get("TWILIO_FROM"), svc = Deno.env.get("TWILIO_MESSAGING_SERVICE_SID");
    if (!sid || !token || (!from && !svc)) throw new Error("Text messages are not set up yet. Please tell the administrator.");
    const form = new URLSearchParams({ To: to, Body: text });
    if (svc) form.set("MessagingServiceSid", svc);
    else form.set("From", from!);
    const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: { Authorization: "Basic " + btoa(`${sid}:${token}`), "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (!r.ok) throw new Error("The text message could not be sent. Check the number and try again.");
    return;
  }
  if (provider === "semaphore") {
    const key = Deno.env.get("SEMAPHORE_API_KEY");
    if (!key) throw new Error("Text messages are not set up yet. Please tell the administrator.");
    const form = new URLSearchParams({ apikey: key, number: to.replace("+", ""), message: text });
    const sender = Deno.env.get("SEMAPHORE_SENDER");
    if (sender) form.set("sendername", sender);
    const r = await fetch("https://api.semaphore.co/api/v4/messages", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (!r.ok) throw new Error("The text message could not be sent. Check the number and try again.");
    return;
  }
  throw new Error("Text messages are not set up yet. Please tell the administrator.");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false },
    });
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: caller, error: callerErr } = await admin.auth.getUser(token);
    if (callerErr || !caller?.user) return reply({ error: "Please sign in again." }, 401);
    const uid = caller.user.id;

    const { data: me } = await admin
      .from("profiles")
      .select("id,email,phone,role,suspended,contact_verified_at")
      .eq("id", uid)
      .maybeSingle();
    if (!me || me.suspended) return reply({ error: "This account is not active." }, 403);
    if (me.role === "admin" || me.contact_verified_at) return reply({ ok: true, verified: true });

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "");
    const phone = normalizePhone(me.phone ?? "");
    const email = String(me.email ?? "");

    if (action === "options") {
      return reply({
        ok: true,
        email: email ? maskEmail(email) : "",
        phone: phone ? maskPhone(phone) : "",
        emailReady: emailReady() && !!email,
        smsReady: smsReady() && !!phone,
      });
    }

    const channel = String(body.channel ?? "");
    if (action === "send") {
      const useEmail = channel !== "sms", useSms = channel !== "email"; // no channel = both (older app)
      if (channel && channel !== "email" && channel !== "sms") return reply({ error: "Choose email or text message." }, 400);
      if (useSms && !phone) return reply({ error: "The mobile number on this account is not valid. Ask the administrator to fix it." }, 400);
      if (useEmail && !email) return reply({ error: "This account has no email address." }, 400);

      const now = Date.now();
      const { data: rows } = await admin.from("verification_codes").select("*").eq("user_id", uid);
      const prev = (rows ?? []).find((r) => r.channel === (useEmail ? "email" : "sms"));
      if (prev) {
        const since = (now - new Date(prev.sent_at).getTime()) / 1000;
        if (since < COOLDOWN_SECONDS) {
          return reply({ error: `Please wait ${Math.ceil(COOLDOWN_SECONDS - since)} seconds before asking for a new code.` }, 429);
        }
      }
      const windowStart = prev && now - new Date(prev.window_start).getTime() < 3600_000 ? new Date(prev.window_start) : new Date(now);
      const sends = prev && windowStart.getTime() === new Date(prev.window_start).getTime() ? prev.sends : 0;
      if (sends >= MAX_SENDS_PER_HOUR) return reply({ error: "Too many codes were requested. Try again in an hour." }, 429);

      const emailCode = newCode(), smsCode = newCode();
      const errors: string[] = [];
      if (useEmail) { try { await sendEmail(email, emailCode); } catch (e) { errors.push((e as Error).message); } }
      if (useSms) { try { await sendSms(phone!, smsCode); } catch (e) { errors.push((e as Error).message); } }
      if (errors.length) return reply({ error: errors.join(" ") }, 502);

      const expires = new Date(now + CODE_MINUTES * 60_000).toISOString();
      const common = { user_id: uid, expires_at: expires, attempts: 0, sent_at: new Date(now).toISOString(), window_start: windowStart.toISOString(), sends: sends + 1 };
      const out: Record<string, unknown>[] = [];
      if (useEmail) out.push({ ...common, channel: "email", code_hash: await hash(uid, "email", emailCode) });
      if (useSms) out.push({ ...common, channel: "sms", code_hash: await hash(uid, "sms", smsCode) });
      if (channel) await admin.from("verification_codes").delete().eq("user_id", uid).eq("channel", channel === "email" ? "sms" : "email");
      const { error } = await admin.from("verification_codes").upsert(out);
      if (error) return reply({ error: "Could not save the code. Try again." }, 500);
      return reply({
        ok: true, channel: channel || "both", cooldown: COOLDOWN_SECONDS,
        ...(useEmail ? { email: maskEmail(email) } : {}), ...(useSms ? { phone: maskPhone(phone!) } : {}),
      });
    }

    if (action === "check" && (channel === "email" || channel === "sms")) {
      const code = String(body.code ?? "").trim();
      if (!/^\d{6}$/.test(code)) return reply({ error: "Enter the 6-digit code." }, 400);
      const { data: rows } = await admin.from("verification_codes").select("*").eq("user_id", uid);
      const row = (rows ?? []).find((r) => r.channel === channel);
      if (!row) return reply({ error: "Ask for a new code first." }, 400);
      if (new Date(row.expires_at).getTime() < Date.now()) return reply({ error: "The code expired. Ask for a new code." }, 400);
      if (row.attempts >= MAX_ATTEMPTS) return reply({ error: "Too many wrong tries. Ask for a new code." }, 429);
      if ((await hash(uid, channel, code)) !== row.code_hash) {
        await admin.from("verification_codes").update({ attempts: row.attempts + 1 }).eq("user_id", uid).eq("channel", channel);
        return reply({ error: "That code is not correct." }, 400);
      }
      const { error } = await admin.from("profiles").update({ contact_verified_at: new Date().toISOString() }).eq("id", uid);
      if (error) return reply({ error: "Could not finish. Try again." }, 500);
      await admin.from("verification_codes").delete().eq("user_id", uid);
      return reply({ ok: true, verified: true });
    }

    if (action === "check") {
      const emailCode = String(body.emailCode ?? "").trim();
      const smsCode = String(body.smsCode ?? "").trim();
      if (!/^\d{6}$/.test(emailCode) || !/^\d{6}$/.test(smsCode)) {
        return reply({ error: "Enter both 6-digit codes." }, 400);
      }
      const { data: rows } = await admin.from("verification_codes").select("*").eq("user_id", uid);
      const e = (rows ?? []).find((r) => r.channel === "email");
      const s = (rows ?? []).find((r) => r.channel === "sms");
      if (!e || !s) return reply({ error: "Ask for new codes first." }, 400);
      if (new Date(e.expires_at).getTime() < Date.now() || new Date(s.expires_at).getTime() < Date.now()) {
        return reply({ error: "The codes expired. Ask for new codes." }, 400);
      }
      if (e.attempts >= MAX_ATTEMPTS || s.attempts >= MAX_ATTEMPTS) {
        return reply({ error: "Too many wrong tries. Ask for new codes." }, 429);
      }
      const okEmail = (await hash(uid, "email", emailCode)) === e.code_hash;
      const okSms = (await hash(uid, "sms", smsCode)) === s.code_hash;
      if (!okEmail || !okSms) {
        await admin.from("verification_codes").update({ attempts: e.attempts + 1 }).eq("user_id", uid).eq("channel", "email");
        await admin.from("verification_codes").update({ attempts: s.attempts + 1 }).eq("user_id", uid).eq("channel", "sms");
        const which = !okEmail && !okSms ? "Both codes are" : !okEmail ? "The email code is" : "The text message code is";
        return reply({ error: `${which} not correct.` }, 400);
      }
      const { error } = await admin.from("profiles").update({ contact_verified_at: new Date().toISOString() }).eq("id", uid);
      if (error) return reply({ error: "Could not finish. Try again." }, 500);
      await admin.from("verification_codes").delete().eq("user_id", uid);
      return reply({ ok: true, verified: true });
    }

    return reply({ error: "Unknown action." }, 400);
  } catch (e) {
    return reply({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
