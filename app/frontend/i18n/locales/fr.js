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
      sessions: "Conversations",
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
        "Silence laissé après une pause naturelle avant que les personnages reprennent d’eux-mêmes.",
      retries: "Nouvelles tentatives",
      retry_count: "Nombre de tentatives",
      retry_base_ms: "Attente de base (ms)",
      retry_max_ms: "Attente maximale (ms)",
      vad: "Détection de la voix",
      vad_settings: "Seuils VAD (JSON)",
      vad_settings_hint:
        "Propre à l’installation. À régler sur place avec le vrai micro et les enceintes ; voir docs/CALIBRATION.md.",
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
      vad_sliders: {
        positive_speech_threshold: "Seuil de parole",
        positive_speech_threshold_hint:
          "Probabilité au-dessus de laquelle une trame compte comme de la parole. À augmenter dans une salle bruyante.",
        negative_speech_threshold: "Seuil de silence",
        negative_speech_threshold_hint:
          "Probabilité en dessous de laquelle une trame compte comme du silence. À garder sous le seuil de parole.",
        min_speech_ms: "Parole minimale",
        min_speech_ms_hint:
          "Les sons plus courts (toux, chaises) sont ignorés.",
        redemption_ms: "Silence de fin de phrase",
        redemption_ms_hint:
          "Silence toléré au milieu d’une phrase avant de considérer la prise de parole terminée.",
        pre_speech_pad_ms: "Marge avant la parole",
        pre_speech_pad_ms_hint:
          "Audio conservé avant le début détecté pour ne pas couper les premières syllabes.",
        interrupt_min_speech_ms: "Délai d’interruption",
        interrupt_min_speech_ms_hint:
          "Parole continue nécessaire, pendant qu’un personnage parle, pour confirmer l’interruption.",
      },
      continue_grace_ms: "Pause avant de se répondre (ms)",
      continue_grace_ms_hint:
        "Silence laissé après une réplique adressée à un autre personnage avant que le groupe y réponde. Assez long pour que le visiteur intervienne.",
      max_unprompted_segments: "Segments sans le visiteur",
      max_unprompted_segments_hint:
        "Nombre de passages que les personnages peuvent enchaîner entre eux avant de s’arrêter et d’attendre le visiteur.",
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
      color: "Couleur",
      color_hint:
        "Utilisée pour le nom dans la transcription et le halo de l’avatar.",
    },
    reset: "défaut",
    sessions: {
      title: "Conversations",
      intro:
        "Les cinquante conversations les plus récentes. Ouvrez-en une pour lire ou copier sa transcription.",
      empty: "Aucune conversation pour l’instant.",
      started: "Début",
      status: "État",
      turns: "Visiteur / personnages",
      duration: "Durée",
      first_line: "Première phrase",
      transcript: "Transcription",
      no_events: "Rien n’a été dit.",
      copy: "Copier la transcription",
      copied: "Copié !",
      delete: "Supprimer",
      delete_confirm:
        "Supprimer définitivement cette conversation et sa transcription ?",
      metrics: "Latence",
      metrics_pending: "Agrégée une fois la conversation terminée.",
      errors: "Erreurs des fournisseurs",
      no_errors: "Aucune erreur de fournisseur.",
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
