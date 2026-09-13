module SignInHelpers
  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }, as: :json
    expect(response).to have_http_status(:ok)
  end

  def json
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include SignInHelpers, type: :request
end
