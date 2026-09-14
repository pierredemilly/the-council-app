import { useEffect, useRef } from "react";
import { t } from "~/i18n";
import { displayText, displayWords } from "~/lib/captions";

const VISITOR_COLOR = "#7dd3fc";
const FALLBACK_COLOR = "#fcd34d";

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
  colors = {},
  preview = "",
}) {
  const bottom = useRef(null);
  const colorOf = (name) => colors[name] ?? FALLBACK_COLOR;

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" });
  }, [events.length, current?.id, preview]);

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
            className="mr-2 font-semibold"
            style={{
              color:
                event.kind === "human" ? VISITOR_COLOR : colorOf(event.speaker),
            }}
          >
            {event.kind === "human" ? t("conversation.you") : event.speaker}
          </span>
          {displayText(event.text)}
          {event.interrupted && <span className="text-stone-400">…</span>}
        </p>
      ))}
      {current && (
        <p className="italic">
          <span
            className="mr-2 font-semibold"
            style={{ color: colorOf(current.speaker) }}
          >
            {current.speaker}
          </span>
          <LiveCaption turn={current} positionMs={positionMs} />
        </p>
      )}
      {preview && (
        <p className="text-stone-300 italic" data-testid="live-preview">
          <span
            className="mr-2 font-semibold not-italic"
            style={{ color: VISITOR_COLOR }}
          >
            {t("conversation.you")}
          </span>
          {preview}
          <span className="text-stone-500">…</span>
        </p>
      )}
      <div ref={bottom} />
    </section>
  );
}
