import { UserCircleIcon } from "@heroicons/react/24/outline";

export default function AvatarStage({ agents, speaker, size = "lg" }) {
  const dimension = size === "lg" ? "h-32 w-32 sm:h-44 sm:w-44" : "h-20 w-20";

  return (
    <ul className="flex flex-wrap items-end justify-center gap-6 sm:gap-12">
      {agents.map((agent) => {
        const active = speaker === agent.name;
        return (
          <li key={agent.position} className="flex flex-col items-center gap-3">
            <div
              className={`${dimension} overflow-hidden rounded-full bg-white ring-4 transition-all duration-300 ${
                active
                  ? "scale-110 shadow-[0_0_60px_rgba(251,191,36,0.6)] ring-amber-400"
                  : "opacity-80 ring-white/20"
              }`}
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
            <span
              className={`text-lg font-medium ${active ? "text-amber-300" : "text-stone-200"}`}
            >
              {agent.name}
            </span>
          </li>
        );
      })}
    </ul>
  );
}
