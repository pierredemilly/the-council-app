import { useEffect, useRef } from "react";
import { t } from "~/i18n";

export default function TranscriptPanel({ events, current }) {
  const bottom = useRef(null);

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" });
  }, [events.length, current?.id]);

  return (
    <section
      aria-live="polite"
      aria-label={t("conversation.transcript")}
      className="max-h-[40vh] space-y-3 overflow-y-auto rounded-xl bg-black/30 p-4 text-left backdrop-blur"
    >
      {events.length === 0 && !current && (
        <p className="text-sm text-stone-400">
          {t("conversation.transcript_empty")}
        </p>
      )}
      {events.map((event) => (
        <p key={event.seq} className="text-stone-100">
          <span
            className={`mr-2 font-semibold ${event.kind === "human" ? "text-sky-300" : "text-amber-300"}`}
          >
            {event.kind === "human" ? t("conversation.you") : event.speaker}
          </span>
          {event.text}
          {event.interrupted && <span className="text-stone-400">…</span>}
        </p>
      ))}
      {current && (
        <p className="text-stone-300 italic">
          <span className="mr-2 font-semibold text-amber-300">
            {current.speaker}
          </span>
          {current.text}
        </p>
      )}
      <div ref={bottom} />
    </section>
  );
}
