import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = JSON.parse(
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!
);

// Get a Firebase access token using the service account
async function getFirebaseAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: FIREBASE_SERVICE_ACCOUNT.client_email,
    sub: FIREBASE_SERVICE_ACCOUNT.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const signingInput = `${encode(header)}.${encode(payload)}`;

  const keyData = FIREBASE_SERVICE_ACCOUNT.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const jwt = `${signingInput}.${btoa(
    String.fromCharCode(...new Uint8Array(signature))
  )
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string
) {
  const projectId = FIREBASE_SERVICE_ACCOUNT.project_id;
  const accessToken = await getFirebaseAccessToken();

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          android: {
            priority: "high",
            notification: { sound: "default" },
          },
        },
      }),
    }
  );

  return response.json();
}

// Mirrors the Dart canUpload logic in lib/main.dart: the owner follows
// owner_is_judge, everyone else follows role === 'judge'; judge_also_plays
// lets a hybrid judge (or judging owner) still count as a player too.
function canUpload(member: any): boolean {
  const isJudging =
    member.role === "owner"
      ? member.owner_is_judge === true
      : member.role === "judge";
  return !isJudging || member.judge_also_plays === true;
}

serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: groups } = await supabase.from("groups").select("id");
    if (!groups || groups.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const startOfDay = new Date();
    startOfDay.setUTCHours(0, 0, 0, 0);
    const endOfDay = new Date(startOfDay);
    endOfDay.setUTCDate(endOfDay.getUTCDate() + 1);

    let sent = 0;

    for (const group of groups) {
      const { data: members } = await supabase
        .from("group_members")
        .select()
        .eq("group_id", group.id);

      if (!members) continue;

      const eligible = members.filter(canUpload);
      if (eligible.length === 0) continue;

      const userIds = eligible.map((m: any) => m.user_id);

      const { data: submissions } = await supabase
        .from("submissions")
        .select("user_id")
        .eq("group_id", group.id)
        .in("user_id", userIds)
        .gte("submitted_at", startOfDay.toISOString())
        .lt("submitted_at", endOfDay.toISOString());

      const submittedIds = new Set(
        (submissions ?? []).map((s: any) => s.user_id)
      );
      const pending = eligible.filter(
        (m: any) => !submittedIds.has(m.user_id)
      );
      if (pending.length === 0) continue;

      const pendingIds = pending.map((m: any) => m.user_id);

      const { data: users } = await supabase
        .from("users")
        .select("id, fcm_token")
        .in("id", pendingIds);

      if (!users) continue;

      for (const member of pending) {
        if (member.notify_submission_reminder === false) continue;

        const user = users.find((u: any) => u.id === member.user_id);
        if (!user?.fcm_token) continue;

        await sendPushNotification(
          user.fcm_token,
          "📸 Don't forget today's photo!",
          "You haven't submitted your battle photo yet today."
        );
        sent++;
      }
    }

    return new Response(JSON.stringify({ sent }), { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
