function csrfMetaTag() {
  return document.querySelector('meta[name="csrf-token"]');
}

function csrfToken() {
  return csrfMetaTag()?.content;
}

function updateCsrfToken(res) {
  const token = res.headers.get("X-CSRF-Token");
  const meta = csrfMetaTag();
  if (token && meta) meta.content = token;
}

async function request(url, { method = "GET", body, formData } = {}) {
  const headers = { Accept: "application/json", "X-CSRF-Token": csrfToken() };
  if (!formData) headers["Content-Type"] = "application/json";
  const res = await fetch(url, {
    method,
    headers,
    body: formData || (body ? JSON.stringify(body) : undefined),
    credentials: "same-origin",
  });

  updateCsrfToken(res);

  const isJson = res.headers.get("content-type")?.includes("application/json");
  const data = isJson ? await res.json() : null;

  if (!res.ok) {
    const message =
      data?.errors?.join(", ") ||
      data?.error ||
      `Request failed (${res.status})`;
    throw new Error(message);
  }

  return data;
}

export const api = {
  get: (url) => request(url),
  post: (url, body) => request(url, { method: "POST", body }),
  put: (url, body) => request(url, { method: "PUT", body }),
  patch: (url, body) => request(url, { method: "PATCH", body }),
  putForm: (url, formData) => request(url, { method: "PUT", formData }),
  delete: (url) => request(url, { method: "DELETE" }),
};
