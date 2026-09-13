import { useEffect, useRef } from "react";
import { t } from "~/i18n";
import { displayText, displayWords } from "~/lib/captions";

// Words whose start time has passed are shown bright; the rest stay dim until spoken.
function LiveCaption({ turn, positionMs }) {
  return (
    <>
      {displayWords(turn.text, turn.timings).map(({ word, timing }, index) => {
        const spoken = timing ? timing.start_ms <= positionMs : true;
        return (
          <span
            key={index}
            className={spoken ? "text-stone-100" : "text-stone-500"}
          >
            {word}{" "}
          </span>
        );
      })}
    </>
  );
}

export default function TranscriptPanel({
  events,
  current,
  positionMs = 0,
  large = false,
}) {
  const bottom = useRef(null);

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" });
  }, [events.length, current?.id]);

  return (
    <section
      aria-live="polite"
      aria-label={t("conversation.transcript")}
      className={`max-h-[40vh] space-y-3 overflow-y-auto rounded-xl bg-black/30 p-4 text-left backdrop-blur ${large ? "text-xl leading-relaxed" : ""}`}
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
          {displayText(event.text)}
          {event.interrupted && <span className="text-stone-400">…</span>}
        </p>
      ))}
      {current && (
        <p className="italic">
          <span className="mr-2 font-semibold text-amber-300">
            {current.speaker}
          </span>
          <LiveCaption turn={current} positionMs={positionMs} />
        </p>
      )}
      <div ref={bottom} />
    </section>
  );
}
