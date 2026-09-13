const KEY = "council.session";

export function loadStoredSession() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const stored = JSON.parse(raw);
    if (!stored?.id || !stored?.token) return null;
    if (stored.resumeDeadline && new Date(stored.resumeDeadline) < new Date()) {
      clearStoredSession();
      return null;
    }
    return stored;
  } catch {
    return null;
  }
}

export function storeSession(session) {
  try {
    localStorage.setItem(
      KEY,
      JSON.stringify({
        id: session.id,
        token: session.token,
        resumeDeadline: session.resumeDeadline,
      })
    );
  } catch {
    // Storage may be unavailable (private mode); resume simply won't work.
  }
}

export function clearStoredSession() {
  try {
    localStorage.removeItem(KEY);
  } catch {
    // ignore
  }
}
