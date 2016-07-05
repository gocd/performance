require 'rest-client'

module GoCD
  class Client
    def initialize(base_url = 'http://localhost:8153/go', rest_client: RestClient)
      @rest_client = rest_client
      @base_url = base_url
    end

    def create_pipeline(data)
      @rest_client.post "#{@base_url}/api/admin/pipelines",
        data,
        :accept =>  'application/vnd.go.cd.v1+json', 
        :content_type =>  'application/json'
    end

    def unpause_pipeline(name)
      @rest_client.post "#{@base_url}/api/pipelines/#{name}/unpause",
        "", :'Confirm'=> true
    end
  end
end
