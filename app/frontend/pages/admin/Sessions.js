import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "~/lib/api";
import FormError from "~/components/FormError";
import { t } from "~/i18n";

const formatDate = (iso) => (iso ? new Date(iso).toLocaleString() : "");
const duration = (session) => {
  const end = session.finalized_at
    ? new Date(session.finalized_at)
    : new Date();
  return Math.max(0, Math.round((end - new Date(session.started_at)) / 1000));
};

export default function Sessions() {
  const [sessions, setSessions] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    api
      .get("/api/admin/sessions")
      .then((data) => setSessions(data.sessions))
      .catch((err) => setError(err.message));
  }, []);

  if (error) return <FormError message={error} />;
  if (!sessions) return <p className="text-gray-500">{t("common.loading")}</p>;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">
          {t("admin.sessions.title")}
        </h1>
        <p className="text-sm text-gray-500">{t("admin.sessions.intro")}</p>
      </div>
      {sessions.length === 0 && (
        <p className="text-gray-500">{t("admin.sessions.empty")}</p>
      )}
      <div className="overflow-x-auto rounded-xl bg-white shadow-sm ring-1 ring-gray-200">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50 text-left text-xs tracking-wide text-gray-500 uppercase">
            <tr>
              <th className="px-4 py-3">{t("admin.sessions.started")}</th>
              <th className="px-4 py-3">{t("admin.sessions.status")}</th>
              <th className="px-4 py-3">{t("admin.sessions.turns")}</th>
              <th className="px-4 py-3">{t("admin.sessions.duration")}</th>
              <th className="px-4 py-3">{t("admin.sessions.first_line")}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {sessions.map((session) => (
              <tr key={session.id} className="hover:bg-gray-50">
                <td className="px-4 py-3 whitespace-nowrap">
                  <Link
                    className="text-indigo-600 hover:underline"
                    to={`/admin/sessions/${session.id}`}
                  >
                    {formatDate(session.started_at)}
                  </Link>
                  <span className="ml-2 text-xs text-gray-400">
                    {session.client_mode}
                  </span>
                </td>
                <td className="px-4 py-3">
                  {session.status}
                  {session.finalize_reason && (
                    <span className="text-gray-400">
                      {" "}
                      · {session.finalize_reason}
                    </span>
                  )}
                </td>
                <td className="px-4 py-3 tabular-nums">
                  {session.human_turns} / {session.agent_turns}
                  {session.interruptions > 0 && (
                    <span className="text-gray-400">
                      {" "}
                      · {session.interruptions} ✂
                    </span>
                  )}
                </td>
                <td className="px-4 py-3 tabular-nums">
                  {duration(session)} s
                </td>
                <td className="max-w-md truncate px-4 py-3 text-gray-600">
                  {session.first_line}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
