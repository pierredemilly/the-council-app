import { useEffect, useState } from "react";
import { api } from "~/lib/api";
import Field, {
  NumberInput,
  Select,
  TextArea,
  TextInput,
} from "~/components/Field";
import JsonField from "~/components/JsonField";
import SaveBar from "~/components/SaveBar";
import FormError from "~/components/FormError";
import { t } from "~/i18n";

function Section({ title, children }) {
  return (
    <section className="space-y-4 rounded-xl bg-white p-6 shadow-sm ring-1 ring-gray-200">
      <h2 className="text-base font-semibold text-gray-900">{title}</h2>
      {children}
    </section>
  );
}

const toOptions = (values) => values.map((v) => ({ value: v, label: v }));

export default function Settings() {
  const [saved, setSaved] = useState(null);
  const [form, setForm] = useState(null);
  const [options, setOptions] = useState(null);
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [justSaved, setJustSaved] = useState(false);

  useEffect(() => {
    api
      .get("/api/admin/config")
      .then((data) => {
        setSaved(data.config);
        setForm(data.config);
        setOptions(data.options);
      })
      .catch((err) => setError(err.message));
  }, []);

  const set = (key) => (value) => {
    setJustSaved(false);
    setForm((prev) => ({ ...prev, [key]: value }));
  };
  const dirty = form && JSON.stringify(form) !== JSON.stringify(saved);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const { id, updated_at, ...config } = form;
      const data = await api.patch("/api/admin/config", { config });
      setSaved(data.config);
      setForm(data.config);
      setJustSaved(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (error && !form) return <FormError message={error} />;
  if (!form) return <p className="text-gray-500">{t("common.loading")}</p>;

  return (
    <form className="space-y-6" onSubmit={handleSubmit}>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">
            {t("admin.settings.title")}
          </h1>
          <p className="text-sm text-gray-500">{t("admin.settings.intro")}</p>
        </div>
        <SaveBar
          saving={saving}
          saved={justSaved}
          error={error}
          dirty={dirty}
        />
      </div>

      <Section title={t("admin.settings.prompt")}>
        <Field
          label={t("admin.settings.global_system_prompt")}
          hint={t("admin.settings.global_system_prompt_hint")}
        >
          <TextArea
            value={form.global_system_prompt}
            onChange={set("global_system_prompt")}
            rows={10}
          />
        </Field>
        <Field label={t("admin.settings.fallback_language")} hint="en, fr, ja…">
          <TextInput
            value={form.fallback_language}
            onChange={set("fallback_language")}
            maxLength={7}
          />
        </Field>
      </Section>

      <Section title={t("admin.settings.llm")}>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label={t("admin.settings.provider")}>
            <Select
              value={form.llm_provider}
              onChange={set("llm_provider")}
              options={toOptions(options.llm_providers)}
            />
          </Field>
          <Field label={t("admin.settings.model")}>
            <TextInput value={form.llm_model} onChange={set("llm_model")} />
          </Field>
          <Field label={t("admin.settings.reasoning_level")}>
            <Select
              value={form.reasoning_level}
              onChange={set("reasoning_level")}
              options={toOptions(options.reasoning_levels)}
            />
          </Field>
        </div>
        <Field
          label={t("admin.settings.max_ai_turns")}
          hint={t("admin.settings.max_ai_turns_hint")}
        >
          <NumberInput
            value={form.max_ai_turns}
            onChange={set("max_ai_turns")}
            min={1}
            max={6}
          />
        </Field>
      </Section>

      <Section title={t("admin.settings.stt")}>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("admin.settings.provider")}>
            <Select
              value={form.stt_provider}
              onChange={set("stt_provider")}
              options={toOptions(options.stt_providers)}
            />
          </Field>
          <Field label={t("admin.settings.model")}>
            <TextInput value={form.stt_model} onChange={set("stt_model")} />
          </Field>
        </div>
        <JsonField
          label={t("admin.settings.provider_settings")}
          hint={t("admin.settings.provider_settings_hint")}
          value={form.stt_settings}
          onChange={set("stt_settings")}
        />
      </Section>

      <Section title={t("admin.settings.tts")}>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("admin.settings.provider")}>
            <Select
              value={form.tts_provider}
              onChange={set("tts_provider")}
              options={toOptions(options.tts_providers)}
            />
          </Field>
          <Field label={t("admin.settings.model")}>
            <TextInput value={form.tts_model} onChange={set("tts_model")} />
          </Field>
        </div>
        <JsonField
          label={t("admin.settings.provider_settings")}
          hint={t("admin.settings.provider_settings_hint")}
          value={form.tts_settings}
          onChange={set("tts_settings")}
        />
      </Section>

      <Section title={t("admin.settings.timing")}>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field
            label={t("admin.settings.inactivity_reset_seconds")}
            hint={t("admin.settings.inactivity_reset_seconds_hint")}
          >
            <NumberInput
              value={form.inactivity_reset_seconds}
              onChange={set("inactivity_reset_seconds")}
              min={30}
              max={3600}
            />
          </Field>
          <Field
            label={t("admin.settings.resume_window_seconds")}
            hint={t("admin.settings.resume_window_seconds_hint")}
          >
            <NumberInput
              value={form.resume_window_seconds}
              onChange={set("resume_window_seconds")}
              min={30}
              max={3600}
            />
          </Field>
          <Field
            label={t("admin.settings.yield_grace_ms")}
            hint={t("admin.settings.yield_grace_ms_hint")}
          >
            <NumberInput
              value={form.yield_grace_ms}
              onChange={set("yield_grace_ms")}
              min={0}
              max={30000}
            />
          </Field>
        </div>
      </Section>

      <Section title={t("admin.settings.retries")}>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label={t("admin.settings.retry_count")}>
            <NumberInput
              value={form.retry_count}
              onChange={set("retry_count")}
              min={0}
              max={10}
            />
          </Field>
          <Field label={t("admin.settings.retry_base_ms")}>
            <NumberInput
              value={form.retry_base_ms}
              onChange={set("retry_base_ms")}
              min={50}
              max={10000}
            />
          </Field>
          <Field label={t("admin.settings.retry_max_ms")}>
            <NumberInput
              value={form.retry_max_ms}
              onChange={set("retry_max_ms")}
              min={100}
              max={60000}
            />
          </Field>
        </div>
      </Section>

      <Section title={t("admin.settings.vad")}>
        <JsonField
          label={t("admin.settings.vad_settings")}
          hint={t("admin.settings.vad_settings_hint")}
          value={form.vad_settings}
          onChange={set("vad_settings")}
          rows={9}
        />
      </Section>

      <Section title={t("admin.settings.deployment")}>
        <Field
          label={t("admin.settings.operating_mode")}
          hint={t("admin.settings.operating_mode_hint")}
        >
          <Select
            value={form.operating_mode}
            onChange={set("operating_mode")}
            options={options.operating_modes.map((v) => ({
              value: v,
              label: t(`admin.settings.operating_modes.${v}`),
            }))}
          />
        </Field>
      </Section>

      <SaveBar saving={saving} saved={justSaved} error={error} dirty={dirty} />
    </form>
  );
}
