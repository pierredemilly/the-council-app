import { useEffect, useState } from "react";
import { api } from "~/lib/api";
import FormError from "~/components/FormError";
import AgentCard from "~/pages/admin/AgentCard";
import { t } from "~/i18n";

export default function Agents() {
  const [agents, setAgents] = useState(null);
  const [voices, setVoices] = useState([]);
  const [voicesError, setVoicesError] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    api
      .get("/api/admin/agents")
      .then((data) => setAgents(data.agents))
      .catch((err) => setError(err.message));
    api
      .get("/api/admin/voices")
      .then((data) => setVoices(data.voices))
      .catch((err) => setVoicesError(err.message));
  }, []);

  const replaceAgent = (agent) =>
    setAgents((prev) => prev.map((a) => (a.id === agent.id ? agent : a)));

  if (error) return <FormError message={error} />;
  if (!agents) return <p className="text-gray-500">{t("common.loading")}</p>;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">
          {t("admin.characters.title")}
        </h1>
        <p className="text-sm text-gray-500">{t("admin.characters.intro")}</p>
      </div>
      {voicesError && (
        <FormError
          message={t("admin.characters.voices_error", { error: voicesError })}
        />
      )}
      {agents.map((agent) => (
        <AgentCard
          key={agent.id}
          agent={agent}
          voices={voices}
          onSaved={replaceAgent}
        />
      ))}
    </div>
  );
}
