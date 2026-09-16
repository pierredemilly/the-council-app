import { useRef, useState } from "react";
import { PhotoIcon, TrashIcon } from "@heroicons/react/24/outline";
import { api } from "~/lib/api";
import Field, { Select, TextArea, TextInput } from "~/components/Field";
import SaveBar from "~/components/SaveBar";
import { t } from "~/i18n";

export default function AgentCard({ agent, voices, onSaved }) {
  const [form, setForm] = useState(agent);
  const [saving, setSaving] = useState(false);
  const [justSaved, setJustSaved] = useState(false);
  const [error, setError] = useState(null);
  const fileInput = useRef(null);

  const dirty = ["name", "personality", "biography", "voice_id", "color"].some(
    (key) => (form[key] ?? "") !== (agent[key] ?? "")
  );

  const set = (key) => (value) => {
    setJustSaved(false);
    setForm((prev) => ({ ...prev, [key]: value }));
  };

  const setVoice = (voiceId) => {
    const voice = voices.find((v) => v.id === voiceId);
    setJustSaved(false);
    setForm((prev) => ({
      ...prev,
      voice_id: voiceId || null,
      voice_name: voice ? voice.name : null,
    }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const { name, personality, biography, voice_id, voice_name, color } =
        form;
      const data = await api.patch(`/api/admin/agents/${agent.id}`, {
        agent: { name, personality, biography, voice_id, voice_name, color },
      });
      onSaved(data.agent);
      setForm(data.agent);
      setJustSaved(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const uploadAvatar = async (file) => {
    if (!file) return;
    setError(null);
    const body = new FormData();
    body.append("avatar", file);
    try {
      const data = await api.putForm(
        `/api/admin/agents/${agent.id}/avatar`,
        body
      );
      onSaved(data.agent);
      setForm((prev) => ({ ...prev, avatar_url: data.agent.avatar_url }));
    } catch (err) {
      setError(err.message);
    } finally {
      if (fileInput.current) fileInput.current.value = "";
    }
  };

  const removeAvatar = async () => {
    setError(null);
    try {
      const data = await api.delete(`/api/admin/agents/${agent.id}/avatar`);
      onSaved(data.agent);
      setForm((prev) => ({ ...prev, avatar_url: null }));
    } catch (err) {
      setError(err.message);
    }
  };

  const voiceOptions = [
    { value: "", label: t("admin.characters.no_voice") },
    ...voices.map((v) => ({ value: v.id, label: v.name })),
  ];
  if (form.voice_id && !voices.some((v) => v.id === form.voice_id)) {
    voiceOptions.push({
      value: form.voice_id,
      label: form.voice_name || form.voice_id,
    });
  }

  return (
    <form
      className="grid gap-6 rounded-xl bg-white p-6 shadow-sm ring-1 ring-gray-200 md:grid-cols-[10rem_1fr]"
      onSubmit={handleSubmit}
    >
      <div className="flex flex-col items-center gap-3">
        <div
          className="flex h-40 w-40 items-center justify-center overflow-hidden rounded-full bg-gray-100 ring-4"
          style={{ "--tw-ring-color": form.color ?? "#f59e0b" }}
        >
          {form.avatar_url ? (
            <img
              src={form.avatar_url}
              alt={form.name}
              className="h-full w-full object-cover"
            />
          ) : (
            <PhotoIcon className="h-12 w-12 text-gray-300" />
          )}
        </div>
        <input
          ref={fileInput}
          type="file"
          accept="image/png,image/jpeg,image/webp"
          className="hidden"
          onChange={(e) => uploadAvatar(e.target.files[0])}
        />
        <div className="flex gap-2 text-sm">
          <button
            type="button"
            className="rounded-md px-2 py-1 text-indigo-600 ring-1 ring-indigo-600 hover:bg-indigo-50"
            onClick={() => fileInput.current?.click()}
          >
            {t("admin.characters.upload_avatar")}
          </button>
          {form.avatar_url && (
            <button
              type="button"
              className="rounded-md p-1 text-gray-500 hover:bg-gray-100"
              onClick={removeAvatar}
              aria-label={t("admin.characters.remove_avatar")}
            >
              <TrashIcon className="h-5 w-5" />
            </button>
          )}
        </div>
      </div>

      <div className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("admin.characters.name")}>
            <TextInput
              value={form.name}
              onChange={set("name")}
              maxLength={40}
              required
            />
          </Field>
          <Field
            label={t("admin.characters.color")}
            hint={t("admin.characters.color_hint")}
          >
            <div className="flex items-center gap-3">
              <input
                type="color"
                value={form.color ?? "#f59e0b"}
                onChange={(e) => set("color")(e.target.value)}
                className="h-9 w-14 cursor-pointer rounded border border-gray-300 bg-white p-1"
                aria-label={t("admin.characters.color")}
              />
              <span
                className="rounded-full px-3 py-1 text-sm font-semibold text-stone-900"
                style={{ backgroundColor: form.color ?? "#f59e0b" }}
              >
                {form.name}
              </span>
            </div>
          </Field>
          <Field label={t("admin.characters.voice")}>
            <Select
              value={form.voice_id ?? ""}
              onChange={setVoice}
              options={voiceOptions}
            />
          </Field>
        </div>
        <Field
          label={t("admin.characters.biography")}
          hint={t("admin.characters.biography_hint")}
        >
          <TextArea
            value={form.biography ?? ""}
            onChange={set("biography")}
            rows={5}
          />
        </Field>
        <Field
          label={t("admin.characters.personality")}
          hint={t("admin.characters.personality_hint")}
        >
          <TextArea
            value={form.personality}
            onChange={set("personality")}
            rows={12}
          />
        </Field>
        <SaveBar
          saving={saving}
          saved={justSaved}
          error={error}
          dirty={dirty}
        />
      </div>
    </form>
  );
}
