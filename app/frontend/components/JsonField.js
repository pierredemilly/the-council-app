import { useEffect, useState } from "react";
import Field, { TextArea } from "~/components/Field";
import { t } from "~/i18n";

// Edits a JSON object as text and only propagates it once it parses.
export default function JsonField({ label, hint, value, onChange, rows = 6 }) {
  const [text, setText] = useState(() => JSON.stringify(value ?? {}, null, 2));
  const [invalid, setInvalid] = useState(false);

  useEffect(() => {
    setText(JSON.stringify(value ?? {}, null, 2));
    setInvalid(false);
  }, [value]);

  const handleChange = (next) => {
    setText(next);
    try {
      const parsed = JSON.parse(next);
      if (
        parsed === null ||
        typeof parsed !== "object" ||
        Array.isArray(parsed)
      ) {
        throw new Error("not an object");
      }
      setInvalid(false);
      onChange(parsed);
    } catch {
      setInvalid(true);
    }
  };

  return (
    <Field label={label} hint={invalid ? t("admin.json_invalid") : hint}>
      <TextArea
        value={text}
        onChange={handleChange}
        rows={rows}
        aria-invalid={invalid}
      />
    </Field>
  );
}
