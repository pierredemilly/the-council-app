module Api
  module Admin
    class AgentsController < BaseController
      before_action :set_agent, except: :index

      def index
        render json: { agents: AgentSerializer.new(Agent.ordered).serializable_hash }
      end

      def update
        if @agent.update(agent_params)
          render json: { agent: AgentSerializer.new(@agent).serializable_hash }
        else
          render_invalid(@agent)
        end
      end

      def avatar
        @agent.avatar.attach(params.require(:avatar))
        if @agent.valid?
          render json: { agent: AgentSerializer.new(@agent).serializable_hash }
        else
          @agent.avatar.detach
          render_invalid(@agent)
        end
      end

      def destroy_avatar
        @agent.avatar.purge_later
        render json: { agent: AgentSerializer.new(@agent.reload).serializable_hash }
      end

      private

      def set_agent
        @agent = Agent.find(params[:id])
      end

      def agent_params
        params.require(:agent).permit(:name, :personality, :voice_id, :voice_name, :color)
      end
    end
  end
end
