module GoConstants

    AUTH_HEADER = "Basic #{Base64.encode64('admin:badger')}".freeze
    BASE_URL = 'http://localhost:8353/go'.freeze
end
