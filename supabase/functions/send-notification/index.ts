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

serve(async (req) => {
  try {
    const { type, groupId, senderId, senderName } = await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get all group members except the sender
    const { data: members } = await supabase
      .from("group_members")
      .select()
      .eq("group_id", groupId)
      .neq("user_id", senderId);

    if (!members || members.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const userIds = members.map((m: any) => m.user_id);

    // Get FCM tokens and notification preferences
    const { data: users } = await supabase
      .from("users")
      .select("id, fcm_token, username")
      .in("id", userIds);

    if (!users) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    let sent = 0;

    for (const member of members) {
      const user = users.find((u: any) => u.id === member.user_id);
      if (!user?.fcm_token) continue;

      let title = "";
      let body = "";
      let shouldSend = false;

      if (type === "chat" && member.notify_chat !== false) {
        title = "New message in My Nemesis";
        body = `${senderName}: ${req.body}`;
        shouldSend = true;
      } else if (type === "upload" && member.notify_uploads !== false) {
        title = "New photo uploaded!";
        body = `${senderName} just submitted their photo for today's battle.`;
        shouldSend = true;
      } else if (type === "score" && member.notify_judge_reminder !== false) {
        title = "Your photo was scored!";
        body = `A judge has scored your photo in ${senderName}.`;
        shouldSend = true;
      }

      if (shouldSend) {
        await sendPushNotification(user.fcm_token, title, body);
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