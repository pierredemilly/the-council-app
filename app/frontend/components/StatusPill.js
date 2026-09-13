import { t } from "~/i18n";

const STYLES = {
  listening: "bg-emerald-500/20 text-emerald-200 ring-emerald-400/40",
  processing: "bg-sky-500/20 text-sky-200 ring-sky-400/40",
  speaking: "bg-amber-500/20 text-amber-200 ring-amber-400/40",
  user_speaking: "bg-sky-500/20 text-sky-100 ring-sky-300/50",
  errored: "bg-red-500/20 text-red-200 ring-red-400/40",
  reconnecting: "bg-stone-500/30 text-stone-200 ring-stone-400/40",
  starting: "bg-stone-500/30 text-stone-200 ring-stone-400/40",
  finalized: "bg-stone-500/30 text-stone-200 ring-stone-400/40",
};

export default function StatusPill({ phase }) {
  return (
    <span
      role="status"
      className={`inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-medium ring-1 ${STYLES[phase] ?? STYLES.starting}`}
    >
      {["listening", "processing", "user_speaking"].includes(phase) && (
        <span className="h-2 w-2 animate-pulse rounded-full bg-current" />
      )}
      {t(`conversation.status.${phase}`)}
    </span>
  );
}
