import { useState } from "react";
import { HandRaisedIcon, PaperAirplaneIcon } from "@heroicons/react/24/outline";
import { t } from "~/i18n";

// Typed input doubles as the accessibility path and, until the microphone lands, the only one.
export default function TextComposer({
  onSpeak,
  onInterrupt,
  speaking,
  disabled,
}) {
  const [text, setText] = useState("");
  const [error, setError] = useState(null);

  const submit = async (event) => {
    event.preventDefault();
    const line = text.trim();
    if (!line) return;
    setError(null);
    try {
      await onSpeak(line);
      setText("");
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <form onSubmit={submit} className="flex w-full max-w-2xl flex-col gap-2">
      <div className="flex gap-2">
        <input
          className="min-w-0 flex-1 rounded-full bg-white/10 px-4 py-3 text-stone-100 ring-1 ring-white/20 placeholder:text-stone-400 focus:ring-2 focus:ring-amber-400 focus:outline-none"
          placeholder={t("conversation.type_placeholder")}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onFocus={() => speaking && onInterrupt()}
          disabled={disabled}
          maxLength={2000}
          aria-label={t("conversation.type_placeholder")}
        />
        {speaking ? (
          <button
            type="button"
            onClick={onInterrupt}
            className="flex items-center gap-2 rounded-full bg-amber-400 px-4 py-3 font-semibold text-stone-900 hover:bg-amber-300"
          >
            <HandRaisedIcon className="h-5 w-5" />
            {t("conversation.interrupt")}
          </button>
        ) : (
          <button
            type="submit"
            disabled={disabled || !text.trim()}
            className="flex items-center gap-2 rounded-full bg-sky-500 px-4 py-3 font-semibold text-white hover:bg-sky-400 disabled:opacity-40"
            aria-label={t("conversation.send")}
          >
            <PaperAirplaneIcon className="h-5 w-5" />
          </button>
        )}
      </div>
      {error && <p className="text-sm text-red-300">{error}</p>}
    </form>
  );
}
