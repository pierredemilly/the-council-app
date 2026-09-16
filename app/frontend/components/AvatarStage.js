import { UserCircleIcon } from "@heroicons/react/24/outline";

const FALLBACK_COLOR = "#f59e0b";

export default function AvatarStage({ agents, speaker, size = "lg" }) {
  const dimension = size === "lg" ? "h-32 w-32 sm:h-44 sm:w-44" : "h-20 w-20";

  return (
    <ul className="flex flex-wrap items-end justify-center gap-6 sm:gap-20">
      {agents.map((agent) => {
        const active = speaker === agent.name;
        const color = agent.color ?? FALLBACK_COLOR;
        return (
          <li key={agent.position} className="flex flex-col items-center gap-3">
            <div
              className={`${dimension} overflow-hidden rounded-full bg-white ring-4 transition-all duration-300 ${
                active ? "scale-110" : "opacity-80"
              }`}
              style={{
                "--tw-ring-color": active ? color : "rgba(255,255,255,0.2)",
                boxShadow: active ? `0 0 60px ${color}99` : undefined,
              }}
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
              className="text-lg font-medium"
              style={{ color: active ? color : "#e7e5e4" }}
            >
              {agent.name}
            </span>
          </li>
        );
      })}
    </ul>
  );
}
