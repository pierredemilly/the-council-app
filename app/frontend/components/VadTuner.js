import { useEffect, useState } from "react";
import { XMarkIcon } from "@heroicons/react/24/outline";
import SliderField from "~/components/SliderField";
import FormError from "~/components/FormError";
import { api } from "~/lib/api";
import { t } from "~/i18n";

export const VAD_SLIDERS = [
  { key: "positive_speech_threshold", step: 0.05, unit: "" },
  { key: "negative_speech_threshold", step: 0.05, unit: "" },
  { key: "min_speech_ms", step: 10, unit: " ms" },
  { key: "redemption_ms", step: 50, unit: " ms" },
  { key: "pre_speech_pad_ms", step: 10, unit: " ms" },
  { key: "interrupt_min_speech_ms", step: 50, unit: " ms" },
];

const METER_MS = 100;

// Live speech probability against the two thresholds, so the admin sees what the detector sees.
function SpeechMeter({ read, settings, userSpeaking }) {
  const [probability, setProbability] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => setProbability(read()), METER_MS);
    return () => clearInterval(timer);
  }, [read]);
  const percent = (value) => `${Math.round((value ?? 0) * 100)}%`;
  return (
    <div>
      <div className="mb-1 flex items-center justify-between text-xs text-gray-600">
        <span>{t("conversation.tune.meter")}</span>
        <span className="tabular-nums">
          {userSpeaking
            ? t("conversation.tune.speech_detected")
            : percent(probability)}
        </span>
      </div>
      <div className="relative h-3 overflow-hidden rounded-full bg-gray-200">
        <div
          className={`h-full transition-[width] duration-100 ${userSpeaking ? "bg-red-500" : "bg-indigo-400"}`}
          style={{ width: percent(probability) }}
        />
        <span
          className="absolute inset-y-0 w-0.5 bg-red-600"
          style={{ left: percent(settings.positive_speech_threshold) }}
          title={t("admin.settings.vad_sliders.positive_speech_threshold")}
        />
        <span
          className="absolute inset-y-0 w-0.5 bg-gray-500"
          style={{ left: percent(settings.negative_speech_threshold) }}
          title={t("admin.settings.vad_sliders.negative_speech_threshold")}
        />
      </div>
    </div>
  );
}

// Admin-only drawer on the public page: sliders act on the running microphone at once, Save persists them.
export default function VadTuner({
  onClose,
  tuneVad,
  readSpeechProbability,
  userSpeaking,
  micState,
}) {
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
        const settings = {
          ...data.options.vad_defaults,
          ...data.config.vad_settings,
        };
        setSaved(settings);
        setForm(settings);
        setOptions(data.options);
      })
      .catch((err) => setError(err.message));
  }, []);

  const apply = (next) => {
    setJustSaved(false);
    setForm(next);
    tuneVad(next);
  };

  const revert = () => apply(saved);

  const save = async () => {
    setSaving(true);
    setError(null);
    try {
      const data = await api.put("/api/admin/config", {
        config: { vad_settings: form },
      });
      const settings = {
        ...data.options.vad_defaults,
        ...data.config.vad_settings,
      };
      setSaved(settings);
      setForm(settings);
      setJustSaved(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const dirty = form && JSON.stringify(form) !== JSON.stringify(saved);

  return (
    <aside
      aria-label={t("conversation.tune.title")}
      className="fixed right-4 bottom-16 z-20 max-h-[80vh] w-[min(24rem,calc(100vw-2rem))] overflow-y-auto rounded-2xl bg-white p-5 text-left text-gray-900 shadow-2xl ring-1 ring-black/10"
    >
      <div className="mb-3 flex items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold">
            {t("conversation.tune.title")}
          </h2>
          <p className="text-xs text-gray-500">
            {micState === "on"
              ? t("conversation.tune.hint_live")
              : t("conversation.tune.hint_idle")}
          </p>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="rounded-full p-1 text-gray-500 hover:bg-gray-100"
          aria-label={t("conversation.tune.close")}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>
      </div>
      <FormError message={error} />
      {form && options && (
        <div className="space-y-5">
          {micState === "on" && (
            <SpeechMeter
              read={readSpeechProbability}
              settings={form}
              userSpeaking={userSpeaking}
            />
          )}
          {VAD_SLIDERS.map(({ key, step, unit }) => (
            <SliderField
              key={key}
              label={t(`admin.settings.vad_sliders.${key}`)}
              hint={t(`admin.settings.vad_sliders.${key}_hint`)}
              value={form[key]}
              defaultValue={options.vad_defaults[key]}
              min={options.vad_ranges[key].min}
              max={options.vad_ranges[key].max}
              step={step}
              unit={unit}
              onChange={(v) => apply({ ...form, [key]: v })}
            />
          ))}
          <div className="flex items-center justify-between gap-3 border-t border-gray-100 pt-4 text-sm">
            <span className="text-xs text-gray-500">
              {justSaved
                ? t("conversation.tune.saved")
                : dirty
                  ? t("conversation.tune.unsaved")
                  : ""}
            </span>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={revert}
                disabled={!dirty}
                className="rounded-md px-3 py-1.5 font-medium text-gray-700 ring-1 ring-gray-300 hover:bg-gray-50 disabled:opacity-40"
              >
                {t("conversation.tune.revert")}
              </button>
              <button
                type="button"
                onClick={save}
                disabled={!dirty || saving}
                className="rounded-md bg-indigo-600 px-3 py-1.5 font-semibold text-white hover:bg-indigo-500 disabled:opacity-40"
              >
                {saving ? t("common.saving") : t("conversation.tune.save")}
              </button>
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
