# Transport only: authorizes the subscription, validates messages and hands them to the orchestrator.
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @session = Conversation::SessionStore.find_authorized(params[:sessionId], params[:token])
    return reject unless @session&.active?

    stream_from Conversation::Protocol.stream_name(@session.id)
    orchestrator.connected!
    transmit Conversation::Protocol.envelope(@session, "session.ready", orchestrator.ready_payload)
  end

  def unsubscribed
    orchestrator.disconnected! if @session
  end

  def event(data)
    type, payload = Conversation::Protocol.parse_client!(data)
    if type == "client.heartbeat"
      orchestrator.heartbeat!
      transmit Conversation::Protocol.envelope(@session, "server.heartbeat", { serverTime: Time.current.iso8601(3) })
    else
      orchestrator.dispatch(type, payload)
    end
  rescue Conversation::Protocol::InvalidMessage => e
    transmit Conversation::Protocol.envelope(@session, "error.recoverable", { code: "invalid_message", message: e.message, retryable: false })
  rescue Conversation::Inactive
    transmit Conversation::Protocol.envelope(@session, "state.changed", { status: "finalized", reason: @session.finalize_reason })
  end

  private

  def orchestrator
    @orchestrator ||= Conversation::Orchestrator.new(@session)
  end
end
