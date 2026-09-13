import { fieldClass } from "~/components/AuthLayout";

export default function Field({ label, hint, children }) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium text-gray-700">
        {label}
      </span>
      {children}
      {hint && <span className="mt-1 block text-xs text-gray-500">{hint}</span>}
    </label>
  );
}

export function TextInput({ value, onChange, ...props }) {
  return (
    <input
      className={fieldClass}
      value={value ?? ""}
      onChange={(e) => onChange(e.target.value)}
      {...props}
    />
  );
}

export function NumberInput({ value, onChange, ...props }) {
  return (
    <input
      type="number"
      className={fieldClass}
      value={value ?? ""}
      onChange={(e) =>
        onChange(e.target.value === "" ? "" : Number(e.target.value))
      }
      {...props}
    />
  );
}

export function Select({ value, onChange, options, ...props }) {
  return (
    <select
      className={fieldClass}
      value={value ?? ""}
      onChange={(e) => onChange(e.target.value)}
      {...props}
    >
      {options.map((option) => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </select>
  );
}

export function TextArea({ value, onChange, rows = 6, ...props }) {
  return (
    <textarea
      className={`${fieldClass} font-mono`}
      rows={rows}
      value={value ?? ""}
      onChange={(e) => onChange(e.target.value)}
      {...props}
    />
  );
}
