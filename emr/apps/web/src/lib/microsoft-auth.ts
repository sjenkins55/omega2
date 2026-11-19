/**
 * Microsoft OAuth 2.0 Authorization Code flow with PKCE.
 * No MSAL library needed — uses the browser's built-in Web Crypto API.
 *
 * Flow:
 *   1. microsoftLogin()       → redirects to Microsoft
 *   2. Microsoft redirects to /login/callback?code=...&state=...
 *   3. handleMicrosoftCallback() → exchanges code for tokens
 *   4. Returns { id_token } which you POST to /api/v1/auth/microsoft
 *
 * Required env vars (NEXT_PUBLIC_*):
 *   NEXT_PUBLIC_AZURE_CLIENT_ID   – App Registration client ID
 *   NEXT_PUBLIC_AZURE_TENANT_ID   – Tenant UUID or "common" (default)
 */

const CLIENT_ID  = process.env.NEXT_PUBLIC_AZURE_CLIENT_ID ?? "";
const TENANT_ID  = process.env.NEXT_PUBLIC_AZURE_TENANT_ID ?? "common";
const SCOPES     = ["openid", "profile", "email"].join(" ");

// Redirect URI must be registered in Azure App Registration
function redirectUri() {
  return typeof window !== "undefined"
    ? `${window.location.origin}/login/callback`
    : "";
}

// ── PKCE helpers ────────────────────────────────────────────────────────────

function randomBase64Url(bytes = 32): string {
  const arr = crypto.getRandomValues(new Uint8Array(bytes));
  return btoa(String.fromCharCode(...arr))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function sha256Base64Url(plain: string): Promise<string> {
  const encoded = new TextEncoder().encode(plain);
  const hash = await crypto.subtle.digest("SHA-256", encoded);
  return btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

// ── Public API ───────────────────────────────────────────────────────────────

/** Returns true if Microsoft SSO is configured (env vars present). */
export function isMicrosoftSSOEnabled(): boolean {
  return Boolean(CLIENT_ID);
}

/**
 * Begin Microsoft login — generates PKCE, saves state/verifier to sessionStorage,
 * then redirects the browser to Microsoft's authorization endpoint.
 */
export async function microsoftLogin(): Promise<void> {
  if (!CLIENT_ID) throw new Error("NEXT_PUBLIC_AZURE_CLIENT_ID is not set");

  const state        = randomBase64Url(16);
  const codeVerifier = randomBase64Url(32);
  const codeChallenge = await sha256Base64Url(codeVerifier);

  sessionStorage.setItem("ms_oauth_state",    state);
  sessionStorage.setItem("ms_code_verifier",  codeVerifier);

  const params = new URLSearchParams({
    client_id:             CLIENT_ID,
    response_type:         "code",
    redirect_uri:          redirectUri(),
    response_mode:         "query",
    scope:                 SCOPES,
    state,
    code_challenge:        codeChallenge,
    code_challenge_method: "S256",
    prompt:                "select_account",
  });

  window.location.href =
    `https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/authorize?${params}`;
}

/**
 * Call from /login/callback after Microsoft redirects back.
 * Exchanges the authorization code for tokens and returns { id_token, access_token }.
 * Throws on any error (state mismatch, exchange failure, etc.)
 */
export async function handleMicrosoftCallback(): Promise<{ id_token: string; access_token: string }> {
  const params      = new URLSearchParams(window.location.search);
  const code        = params.get("code");
  const returnedState = params.get("state");
  const error       = params.get("error");
  const errorDesc   = params.get("error_description");

  if (error) throw new Error(errorDesc ?? error);
  if (!code) throw new Error("No authorization code in callback URL");

  const savedState    = sessionStorage.getItem("ms_oauth_state");
  const codeVerifier  = sessionStorage.getItem("ms_code_verifier");
  sessionStorage.removeItem("ms_oauth_state");
  sessionStorage.removeItem("ms_code_verifier");

  if (!savedState || returnedState !== savedState) {
    throw new Error("OAuth state mismatch — possible CSRF attempt");
  }
  if (!codeVerifier) {
    throw new Error("Code verifier missing from session — please try signing in again");
  }

  const body = new URLSearchParams({
    client_id:    CLIENT_ID,
    grant_type:   "authorization_code",
    code,
    redirect_uri: redirectUri(),
    code_verifier: codeVerifier,
    scope:        SCOPES,
  });

  const resp = await fetch(
    `https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token`,
    { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body }
  );

  if (!resp.ok) {
    const err = await resp.json().catch(() => ({}));
    throw new Error(err.error_description ?? "Token exchange failed");
  }

  const tokens = await resp.json();
  return { id_token: tokens.id_token, access_token: tokens.access_token };
}
