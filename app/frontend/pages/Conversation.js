import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowPathIcon,
  ComputerDesktopIcon,
  MicrophoneIcon,
  SpeakerWaveIcon,
  XMarkIcon,
} from "@heroicons/react/24/outline";
import AvatarStage from "~/components/AvatarStage";
import StatusPill from "~/components/StatusPill";
import TextComposer from "~/components/TextComposer";
import TranscriptPanel from "~/components/TranscriptPanel";
import useConversation from "~/hooks/useConversation";
import useQueryFlag from "~/hooks/useQueryFlag";
import { api } from "~/lib/api";
import { isReconnecting } from "~/lib/conversationMachine";
import { t } from "~/i18n";

function enterKiosk() {
  const url = new URL(window.location.href);
  url.searchParams.set("kiosk", "true");
  window.history.pushState({}, "", url);
}

export default function Conversation() {
  const kiosk = useQueryFlag("kiosk");
  const clientMode = kiosk ? "kiosk" : "browser";
  const {
    state,
    positionMs,
    audioBlocked,
    unlockAudio,
    start,
    speak,
    interrupt,
    retry,
    leave,
  } = useConversation({ clientMode });
  const [publicConfig, setPublicConfig] = useState(null);
  const [startError, setStartError] = useState(null);

  useEffect(() => {
    api
      .get("/api/public_config")
      .then(setPublicConfig)
      .catch(() => setPublicConfig({ agents: [] }));
  }, []);

  const agents = state.config?.agents ?? publicConfig?.agents ?? [];
  const reconnecting = isReconnecting(state);
  const phase = reconnecting ? "reconnecting" : state.phase;
  const active = state.session && state.phase !== "idle";

  const handleStart = async () => {
    setStartError(null);
    try {
      await start();
    } catch (err) {
      setStartError(err.message);
    }
  };

  return (
    <div className="flex min-h-screen flex-col bg-gradient-to-b from-stone-900 via-stone-950 to-black px-4 py-8 text-center text-stone-100">
      <main className="flex flex-1 flex-col items-center justify-center gap-8">
        <AvatarStage
          agents={agents}
          speaker={state.phase === "speaking" ? state.speaker : null}
        />

        {!active && (
          <div className="flex flex-col items-center gap-4">
            <h1 className="text-3xl font-semibold tracking-tight">
              {t("app.name")}
            </h1>
            <p className="max-w-md text-stone-400">
              {t("conversation.idle_hint")}
            </p>
            <button
              onClick={handleStart}
              className="flex items-center gap-3 rounded-full bg-amber-400 px-8 py-4 text-lg font-semibold text-stone-900 shadow-lg hover:bg-amber-300"
            >
              <MicrophoneIcon className="h-6 w-6" />
              {t("conversation.start")}
            </button>
            {startError && <p className="text-sm text-red-300">{startError}</p>}
          </div>
        )}

        {active && (
          <div className="flex w-full max-w-3xl flex-col items-center gap-5">
            <StatusPill phase={phase} />
            {state.phase === "finalized" && (
              <p className="text-stone-300">{t("conversation.finished")}</p>
            )}
            {state.error && (
              <div className="flex flex-col items-center gap-2 rounded-xl bg-red-500/10 px-4 py-3 ring-1 ring-red-400/40">
                <p className="text-sm text-red-200">{state.error.message}</p>
                {state.error.retryable !== false && (
                  <button
                    onClick={retry}
                    className="flex items-center gap-2 rounded-full bg-red-400 px-4 py-2 text-sm font-semibold text-stone-900"
                  >
                    <ArrowPathIcon className="h-4 w-4" />
                    {t("conversation.retry")}
                  </button>
                )}
              </div>
            )}
            {audioBlocked && (
              <button
                onClick={unlockAudio}
                className="flex items-center gap-2 rounded-full bg-sky-500 px-5 py-2 text-sm font-semibold text-white hover:bg-sky-400"
              >
                <SpeakerWaveIcon className="h-5 w-5" />
                {t("conversation.enable_sound")}
              </button>
            )}
            <TranscriptPanel
              events={state.events}
              current={state.current}
              positionMs={positionMs}
            />
            {state.phase !== "finalized" ? (
              <TextComposer
                onSpeak={speak}
                onInterrupt={interrupt}
                speaking={state.phase === "speaking"}
                disabled={reconnecting}
              />
            ) : (
              <button
                onClick={leave}
                className="rounded-full bg-amber-400 px-6 py-3 font-semibold text-stone-900"
              >
                {t("conversation.new_conversation")}
              </button>
            )}
            {state.events.length === 0 && state.phase === "listening" && (
              <p className="text-sm text-stone-400">
                {t("conversation.speak_first")}
              </p>
            )}
          </div>
        )}
      </main>

      {!kiosk && (
        <footer className="flex items-center justify-between text-xs text-stone-500">
          <Link to="/admin" className="hover:text-stone-300">
            {t("conversation.admin")}
          </Link>
          <div className="flex items-center gap-3">
            {active && state.phase !== "finalized" && (
              <button
                onClick={leave}
                className="flex items-center gap-1 hover:text-stone-300"
              >
                <XMarkIcon className="h-4 w-4" />
                {t("conversation.leave")}
              </button>
            )}
            <button
              onClick={enterKiosk}
              className="flex items-center gap-1 hover:text-stone-300"
              title={t("conversation.kiosk_mode")}
            >
              <ComputerDesktopIcon className="h-4 w-4" />
              {t("conversation.kiosk_mode")}
            </button>
          </div>
        </footer>
      )}
    </div>
  );
}
