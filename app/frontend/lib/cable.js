import { createConsumer } from "@rails/actioncable";

let consumer;

function sharedConsumer() {
  consumer ||= createConsumer();
  return consumer;
}

// One ConversationChannel subscription. Action Cable reconnects on its own with backoff;
// we only report the connection state and forward validated messages.
export function subscribeToConversation({
  sessionId,
  token,
  onMessage,
  onConnection,
  onRejected,
}) {
  const subscription = sharedConsumer().subscriptions.create(
    { channel: "ConversationChannel", sessionId, token },
    {
      initialized: () => onConnection("connecting"),
      connected: () => onConnection("connected"),
      disconnected: () => onConnection("disconnected"),
      rejected: () => onRejected(),
      received: (message) => onMessage(message),
    }
  );

  return {
    send(type, payload = {}) {
      return subscription.perform("event", {
        protocolVersion: 1,
        sessionId,
        type,
        payload,
      });
    },
    // Forces a fresh socket after the automatic backoff has given up or stalled.
    reconnect() {
      sharedConsumer().connection.reopen();
    },
    close() {
      subscription.unsubscribe();
    },
  };
}
