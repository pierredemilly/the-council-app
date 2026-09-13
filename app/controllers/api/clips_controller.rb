module Api
  class ClipsController < BaseController
    def show
      clip = current_session.audio_clips.find(params[:id])
      response.headers["Cache-Control"] = "private, no-store"
      send_data clip.bytes, type: clip.mime, disposition: "inline"
    end
  end
end
