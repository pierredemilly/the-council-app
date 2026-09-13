module Providers
  Voice = Data.define(:id, :name, :preview_url, :labels) do
    def initialize(id:, name:, preview_url: nil, labels: {})
      super
    end
  end
end
