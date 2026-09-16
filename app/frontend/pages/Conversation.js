import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  AdjustmentsHorizontalIcon,
  ArrowPathIcon,
  ComputerDesktopIcon,
  SignalSlashIcon,
  SpeakerXMarkIcon,
  MicrophoneIcon,
  SpeakerWaveIcon,
  XMarkIcon,
} from "@heroicons/react/24/outline";
import AvatarStage from "~/components/AvatarStage";
import MicIndicator from "~/components/MicIndicator";
import StatusPill from "~/components/StatusPill";
import TextComposer from "~/components/TextComposer";
import TranscriptPanel from "~/components/TranscriptPanel";
import VadTuner from "~/components/VadTuner";
import useConversation from "~/hooks/useConversation";
import useQueryFlag from "~/hooks/useQueryFlag";
import { api } from "~/lib/api";
import { useAuth } from "~/lib/auth";
import { isReconnecting } from "~/lib/conversationMachine";
import { t } from "~/i18n";

function enterKiosk() {
  const url = new URL(window.location.href);
  url.searchParams.set("kiosk", "true");
  window.history.pushState({}, "", url);
}

// The player is chosen when the page loads, so switching modes reloads; the session resumes from storage.
function toggleTextOnly(enabled) {
  const url = new URL(window.location.href);
  if (enabled) url.searchParams.delete("textOnly");
  else url.searchParams.set("textOnly", "true");
  window.location.assign(url);
}

export default function Conversation() {
  const kiosk = useQueryFlag("kiosk");
  const textOnly = useQueryFlag("textOnly");
  const clientMode = kiosk ? "kiosk" : "browser";
  const {
    state,
    positionMs,
    audioBlocked,
    micState,
    userSpeaking,
    reconnectExpired,
    unlockAudio,
    startMic,
    start,
    speak,
    interrupt,
    retry,
    retryConnection,
    leave,
    tuneVad,
    readSpeechProbability,
    previewText,
  } = useConversation({ clientMode });
  const { user } = useAuth();
  const [publicConfig, setPublicConfig] = useState(null);
  const [startError, setStartError] = useState(null);
  const [tunerOpen, setTunerOpen] = useState(false);

  useEffect(() => {
    api
      .get("/api/public_config")
      .then(setPublicConfig)
      .catch(() => setPublicConfig({ agents: [] }));
  }, []);

  const agents = state.config?.agents ?? publicConfig?.agents ?? [];
  const colors = Object.fromEntries(agents.map((a) => [a.name, a.color]));
  const reconnecting = isReconnecting(state);
  const phase = reconnecting
    ? "reconnecting"
    : userSpeaking
      ? "user_speaking"
      : state.phase;
  const active = state.session && state.phase !== "idle";

  const tunerButton = user && (
    <button
      type="button"
      onClick={() => setTunerOpen((open) => !open)}
      aria-pressed={tunerOpen}
      className="flex items-center gap-1 rounded-full bg-stone-800/80 px-3 py-1.5 text-stone-300 ring-1 ring-stone-600 backdrop-blur hover:text-stone-100"
    >
      <AdjustmentsHorizontalIcon className="h-4 w-4" />
      {t("conversation.tune.open")}
    </button>
  );

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
      <main className="flex flex-1 flex-col items-center justify-center gap-12">
        <AvatarStage agents={agents} speaker={state.current?.speaker ?? null} />

        {!active && (
          <div className="flex flex-col items-center gap-12">
            <h1 className="text-3xl font-semibold tracking-tight">
              {t("conversation.title")}
            </h1>
            <button
              onClick={handleStart}
              className="flex cursor-pointer items-center gap-3 rounded-full border-2 border-white px-8 py-4 text-lg font-semibold text-white shadow-lg transition-colors hover:bg-white/20"
            >
              <MicrophoneIcon className="h-6 w-6" />
              {t("conversation.start")}
            </button>
            {startError && <p className="text-sm text-red-300">{startError}</p>}
          </div>
        )}

        {active && (
          <div className="flex w-full max-w-3xl flex-col items-center gap-5">
            <div className="flex flex-wrap items-center justify-center gap-3">
              <StatusPill phase={phase} />
              <MicIndicator micState={micState} userSpeaking={userSpeaking} />
              {micState === "denied" && (
                <button
                  onClick={startMic}
                  className="text-xs text-sky-300 underline-offset-2 hover:underline"
                >
                  {t("conversation.mic.retry")}
                </button>
              )}
            </div>
            {reconnecting && (
              <div className="flex flex-col items-center gap-2 rounded-xl bg-stone-500/10 px-4 py-3 ring-1 ring-stone-400/40">
                <p className="flex items-center gap-2 text-sm text-stone-300">
                  <SignalSlashIcon className="h-4 w-4" />
                  {reconnectExpired
                    ? t("conversation.connection_lost")
                    : t("conversation.reconnecting_hint")}
                </p>
                {reconnectExpired && (
                  <button
                    onClick={retryConnection}
                    className="flex items-center gap-2 rounded-full bg-stone-200 px-4 py-2 text-sm font-semibold text-stone-900"
                  >
                    <ArrowPathIcon className="h-4 w-4" />
                    {t("conversation.retry_connection")}
                  </button>
                )}
              </div>
            )}
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
              large={kiosk || textOnly}
              colors={colors}
              preview={previewText}
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

      {user && kiosk && (
        <div className="fixed right-4 bottom-4 z-20">{tunerButton}</div>
      )}
      {user && tunerOpen && (
        <VadTuner
          onClose={() => setTunerOpen(false)}
          tuneVad={tuneVad}
          readSpeechProbability={readSpeechProbability}
          userSpeaking={userSpeaking}
          micState={micState}
        />
      )}

      {!kiosk && (
        <footer className="flex items-center justify-between text-xs text-stone-500">
          <Link to="/admin" className="hover:text-stone-300">
            {t("conversation.admin")}
          </Link>
          <div className="flex items-center gap-3">
            {tunerButton}
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
              onClick={() => toggleTextOnly(textOnly)}
              className="flex items-center gap-1 hover:text-stone-300"
              aria-pressed={textOnly}
            >
              <SpeakerXMarkIcon className="h-4 w-4" />
              {textOnly
                ? t("conversation.sound_on")
                : t("conversation.text_only")}
            </button>
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
