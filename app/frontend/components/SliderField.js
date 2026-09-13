import { t } from "~/i18n";

// A labelled range input that shows its value and can jump back to the default.
export default function SliderField({
  label,
  hint,
  value,
  defaultValue,
  min,
  max,
  step,
  unit = "",
  onChange,
}) {
  const current = value ?? defaultValue;
  return (
    <label className="block">
      <span className="mb-1 flex items-center justify-between text-sm">
        <span className="font-medium text-gray-700">{label}</span>
        <span className="flex items-center gap-2 text-gray-600 tabular-nums">
          {current}
          {unit}
          {current !== defaultValue && (
            <button
              type="button"
              className="text-xs text-indigo-600 hover:underline"
              onClick={() => onChange(defaultValue)}
            >
              {t("admin.reset")}
            </button>
          )}
        </span>
      </span>
      <input
        type="range"
        className="w-full accent-indigo-600"
        min={min}
        max={max}
        step={step}
        value={current}
        onChange={(e) => onChange(Number(e.target.value))}
      />
      {hint && <span className="mt-1 block text-xs text-gray-500">{hint}</span>}
    </label>
  );
}
