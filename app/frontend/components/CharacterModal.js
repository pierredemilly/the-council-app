import { useEffect } from "react";
import { UserCircleIcon, XMarkIcon } from "@heroicons/react/24/outline";
import { t } from "~/i18n";

const FALLBACK_COLOR = "#f59e0b";

export default function CharacterModal({ agent, onClose }) {
  useEffect(() => {
    const onKeyDown = (event) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [onClose]);

  const color = agent.color ?? FALLBACK_COLOR;

  return (
    <div
      className="fixed inset-0 z-30 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={agent.name}
        onClick={(event) => event.stopPropagation()}
        className="relative flex max-h-[85vh] w-full max-w-lg flex-col overflow-y-auto rounded-2xl bg-stone-900 p-8 text-left text-stone-100 shadow-2xl ring-1 ring-stone-700"
      >
        <button
          type="button"
          onClick={onClose}
          aria-label={t("conversation.biography.close")}
          className="absolute top-4 right-4 rounded-full p-1 text-stone-400 hover:bg-stone-800 hover:text-stone-100"
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        <div className="flex flex-col items-center gap-4">
          <div
            className="h-32 w-32 overflow-hidden rounded-full bg-white ring-4"
            style={{ "--tw-ring-color": color }}
          >
            {agent.avatar_url ? (
              <img
                src={agent.avatar_url}
                alt={agent.name}
                className="h-full w-full object-cover"
              />
            ) : (
              <UserCircleIcon className="h-full w-full text-stone-300" />
            )}
          </div>
          <h2 className="text-2xl font-semibold" style={{ color }}>
            {agent.name}
          </h2>
        </div>

        <p className="mt-6 text-base whitespace-pre-line text-stone-300">
          {agent.biography}
        </p>
      </div>
    </div>
  );
}
