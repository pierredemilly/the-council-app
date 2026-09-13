import { MicrophoneIcon } from "@heroicons/react/24/outline";
import { t } from "~/i18n";

// Visitors must always be able to see that the microphone is live.
export default function MicIndicator({ micState, userSpeaking }) {
  if (micState === "off") return null;
  const live = micState === "on";
  return (
    <div
      className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium ring-1 ${
        live
          ? "bg-red-500/15 text-red-200 ring-red-400/40"
          : "bg-stone-500/20 text-stone-300 ring-stone-400/40"
      }`}
      role="status"
      aria-label={t(`conversation.mic.${micState}`)}
    >
      <span className="relative flex h-2.5 w-2.5">
        {live && (
          <span
            className={`absolute inline-flex h-full w-full rounded-full bg-red-400 ${userSpeaking ? "animate-ping" : "opacity-60"}`}
          />
        )}
        <span
          className={`relative inline-flex h-2.5 w-2.5 rounded-full ${live ? "bg-red-400" : "bg-stone-400"}`}
        />
      </span>
      <MicrophoneIcon className="h-4 w-4" />
      {t(`conversation.mic.${micState}`)}
    </div>
  );
}
