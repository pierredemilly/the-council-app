import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ClipboardDocumentIcon, TrashIcon } from "@heroicons/react/24/outline";
import { api } from "~/lib/api";
import FormError from "~/components/FormError";
import { t } from "~/i18n";
import { displayText } from "~/lib/captions";

const LATENCY_KEYS = ["stt_ms", "llm_ms", "first_clip_ms", "first_audio_ms"];

// Plain text with the same conventions as the prompt, so a pasted transcript reads like the script.
function transcriptText(events) {
  return events
    .map(
      (event) =>
        `${event.kind === "human" ? "VISITOR" : event.speaker.toUpperCase()}: ${event.text}${event.interrupted ? " […]" : ""}`
    )
    .join("\n\n");
}

function latencyLine(latency) {
  return LATENCY_KEYS.filter((key) => latency?.[key] != null)
    .map((key) => `${key.replace("_ms", "")} ${latency[key]} ms`)
    .join(" · ");
}

export default function SessionDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    api
      .get(`/api/admin/sessions/${id}`)
      .then(setData)
      .catch((err) => setError(err.message));
  }, [id]);

  const copy = async () => {
    await navigator.clipboard.writeText(transcriptText(data.events));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const remove = async () => {
    if (!window.confirm(t("admin.sessions.delete_confirm"))) return;
    await api.delete(`/api/admin/sessions/${id}`);
    navigate("/admin/sessions");
  };

  if (error) return <FormError message={error} />;
  if (!data) return <p className="text-gray-500">{t("common.loading")}</p>;
  const { session, events, errors } = data;
  const latency = session.metrics?.latency ?? {};

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <Link
            to="/admin/sessions"
            className="text-sm text-indigo-600 hover:underline"
          >
            ← {t("admin.sessions.title")}
          </Link>
          <h1 className="text-2xl font-semibold text-gray-900">
            {new Date(session.started_at).toLocaleString()}
          </h1>
          <p className="text-sm text-gray-500">
            {session.status}
            {session.finalize_reason && ` · ${session.finalize_reason}`}
            {session.language && ` · ${session.language}`} ·{" "}
            {session.client_mode}
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={copy}
            className="flex items-center gap-2 rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
          >
            <ClipboardDocumentIcon className="h-5 w-5" />
            {copied ? t("admin.sessions.copied") : t("admin.sessions.copy")}
          </button>
          <button
            onClick={remove}
            className="flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold text-red-600 ring-1 ring-red-200 hover:bg-red-50"
          >
            <TrashIcon className="h-5 w-5" />
            {t("admin.sessions.delete")}
          </button>
        </div>
      </div>

      <section className="space-y-3 rounded-xl bg-white p-6 shadow-sm ring-1 ring-gray-200">
        <h2 className="text-base font-semibold text-gray-900">
          {t("admin.sessions.transcript")}
        </h2>
        {events.length === 0 && (
          <p className="text-sm text-gray-500">
            {t("admin.sessions.no_events")}
          </p>
        )}
        {events.map((event) => (
          <div key={event.seq} className="text-sm">
            <span
              className={`mr-2 font-semibold ${event.kind === "human" ? "text-sky-700" : "text-amber-700"}`}
            >
              {event.kind === "human" ? t("conversation.you") : event.speaker}
            </span>
            <span className="text-gray-800">{displayText(event.text)}</span>
            {event.interrupted && <span className="text-gray-400"> […]</span>}
            {event.kind === "human" && latencyLine(event.latency) && (
              <span className="ml-2 text-xs text-gray-400">
                {latencyLine(event.latency)}
              </span>
            )}
          </div>
        ))}
      </section>

      <div className="grid gap-6 md:grid-cols-2">
        <section className="space-y-2 rounded-xl bg-white p-6 shadow-sm ring-1 ring-gray-200">
          <h2 className="text-base font-semibold text-gray-900">
            {t("admin.sessions.metrics")}
          </h2>
          {Object.keys(latency).length === 0 && (
            <p className="text-sm text-gray-500">
              {t("admin.sessions.metrics_pending")}
            </p>
          )}
          {Object.entries(latency).map(([key, stats]) => (
            <p key={key} className="text-sm text-gray-700">
              <span className="font-medium">{key.replace("_ms", "")}</span>: p50{" "}
              {stats.p50} ms · p95 {stats.p95} ms · max {stats.max} ms (
              {stats.count})
            </p>
          ))}
          {session.metrics?.llm_input_tokens != null && (
            <p className="text-sm text-gray-700">
              <span className="font-medium">tokens</span>:{" "}
              {session.metrics.llm_input_tokens} in ·{" "}
              {session.metrics.llm_output_tokens} out ·{" "}
              {session.metrics.llm_rejected_scripts ?? 0} rejected scripts
            </p>
          )}
        </section>
        <section className="space-y-2 rounded-xl bg-white p-6 shadow-sm ring-1 ring-gray-200">
          <h2 className="text-base font-semibold text-gray-900">
            {t("admin.sessions.errors")}
          </h2>
          {errors.length === 0 && (
            <p className="text-sm text-gray-500">
              {t("admin.sessions.no_errors")}
            </p>
          )}
          {errors.map((err, index) => (
            <p key={index} className="text-sm text-gray-700">
              <span className="font-medium">{err.stage}</span> · {err.provider}{" "}
              · #{err.attempt} · {err.message}
            </p>
          ))}
        </section>
      </div>
    </div>
  );
}
