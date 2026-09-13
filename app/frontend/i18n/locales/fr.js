export const fr = {
  app: {
    name: "The Council",
  },
  common: {
    error: "Erreur",
    close: "Fermer",
    save: "Enregistrer",
    saving: "Enregistrement...",
    loading: "Chargement…",
  },
  admin: {
    open: "Ouvrir l’admin",
    sign_out: "Se déconnecter",
    saved: "Enregistré.",
    json_invalid: "JSON invalide : la dernière valeur valide sera enregistrée.",
    nav: {
      settings: "Réglages",
      characters: "Personnages",
    },
    settings: {
      title: "Configuration en direct",
      intro:
        "Les changements s’appliquent immédiatement aux nouvelles conversations. Les conversations en cours gardent leur configuration de départ.",
      prompt: "Conversation",
      global_system_prompt: "Prompt système global",
      global_system_prompt_hint:
        "Le brief éditorial partagé par les trois personnages. Les règles structurelles (nombre de tours, format) sont ajoutées automatiquement.",
      fallback_language: "Langue par défaut",
      llm: "Modèle de dialogue (LLM)",
      stt: "Reconnaissance vocale (STT)",
      tts: "Synthèse vocale (TTS)",
      provider: "Fournisseur",
      model: "Modèle",
      reasoning_level: "Niveau de raisonnement",
      max_ai_turns: "Tours IA maximum par segment",
      max_ai_turns_hint:
        "Entre 1 et 6. Chaque personnage parle au plus deux fois par segment.",
      provider_settings: "Réglages du fournisseur (JSON)",
      provider_settings_hint:
        "Transmis tels quels au fournisseur, par exemple la stabilité de la voix ou des indices de transcription.",
      timing: "Temporisation",
      inactivity_reset_seconds:
        "Réinitialisation kiosque après inactivité (secondes)",
      inactivity_reset_seconds_hint:
        "Mode kiosque uniquement : une conversation inactive se réinitialise après ce délai.",
      resume_window_seconds: "Fenêtre de reprise (secondes)",
      resume_window_seconds_hint:
        "Une page fermée peut reprendre sa conversation pendant cette durée.",
      yield_grace_ms: "Délai de grâce (ms)",
      yield_grace_ms_hint:
        "Silence toléré après une ouverture naturelle avant que les personnages reprennent.",
      retries: "Nouvelles tentatives",
      retry_count: "Nombre de tentatives",
      retry_base_ms: "Attente de base (ms)",
      retry_max_ms: "Attente maximale (ms)",
      vad: "Détection de la voix",
      vad_settings: "Seuils VAD (JSON)",
      vad_settings_hint:
        "Propres à l’installation. Les seuils sont des probabilités entre 0 et 1 ; les durées sont en millisecondes.",
      deployment: "Déploiement",
      operating_mode: "Mode de fonctionnement",
      operating_mode_hint:
        "Métadonnée de l’installation ; sans effet sur le comportement en V1.",
      operating_modes: {
        cloud_pi: "Cloud uniquement (client Raspberry Pi)",
        local_gpu: "Serveur local possible (ordinateur GPU)",
      },
      turn_gap_ms: "Pause entre les personnages (ms)",
      turn_gap_ms_hint:
        "Silence laissé entre deux répliques consécutives d’un segment.",
    },
    characters: {
      title: "Personnages",
      intro:
        "Les trois personnages du conseil. Les noms doivent être uniques et sans deux-points.",
      voices_error: "Impossible de charger les voix : {error}",
      name: "Nom",
      voice: "Voix",
      no_voice: "Aucune voix sélectionnée",
      personality: "Fiche de personnalité",
      personality_hint:
        "Format long. Biographie, convictions, vocabulaire, habitudes, façon de contredire les autres.",
      upload_avatar: "Téléverser un avatar",
      remove_avatar: "Retirer l’avatar",
    },
  },
  conversation: {
    idle_hint:
      "Trois personnages vous attendent. Lancez la conversation et parlez en premier : ils vous répondront.",
    start: "Commencer la conversation",
    speak_first:
      "Dites quelque chose pour commencer. Les personnages répondent une fois que vous avez parlé.",
    type_placeholder: "Écrivez ce que vous voulez dire…",
    send: "Envoyer",
    interrupt: "Interrompre",
    retry: "Réessayer",
    finished: "Cette conversation est terminée.",
    new_conversation: "Nouvelle conversation",
    transcript: "Transcription",
    transcript_empty: "La transcription apparaîtra ici.",
    you: "Vous",
    admin: "Admin",
    leave: "Quitter",
    kiosk_mode: "Mode kiosque",
    status: {
      starting: "Connexion…",
      listening: "À l’écoute",
      processing: "Réflexion…",
      speaking: "Parole",
      errored: "Un problème est survenu",
      reconnecting: "Reconnexion…",
      finalized: "Terminée",
      user_speaking: "Vous parlez",
    },
    enable_sound: "Activer le son",
    mic: {
      starting: "Démarrage du micro…",
      on: "Micro actif",
      denied: "Micro indisponible : écrivez plutôt",
      retry: "Autoriser le micro",
    },
    reconnecting_hint: "Connexion perdue, nouvelle tentative…",
    connection_lost: "Toujours pas de connexion.",
    retry_connection: "Réessayer la connexion",
    text_only: "Texte seul",
    sound_on: "Avec le son",
  },
};
