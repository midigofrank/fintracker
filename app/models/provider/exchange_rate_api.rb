class Provider::ExchangeRateApi < Provider
  include ExchangeRateConcept

  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  RateLimitError = Class.new(Error)

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get("#{base_url}/#{api_key}/quota")
      parsed = JSON.parse(response.body)
      parsed["result"] == "success"
    end
  end

  def usage
    with_provider_response do
      response = client.get("#{base_url}/#{api_key}/quota")
      parsed = JSON.parse(response.body)

      if parsed["result"] == "success"
        limit = parsed["plan_quota"]
        used = parsed["requests_used"]

        UsageData.new(
          used: used,
          limit: limit,
          utilization: used.to_f / limit * 100,
          plan: "free"
        )
      else
        raise Error.new("Failed to fetch usage data: #{parsed['error-type']}")
      end
    end
  end

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      response = client.get("#{base_url}/#{api_key}/latest/#{from}")

      parsed = JSON.parse(response.body)

      if parsed["result"] == "error"
        raise Error.new("Failed to fetch exchange rate: #{parsed['error-type']}")
      end

      rate_value = parsed.dig("conversion_rates", to)

      if rate_value.nil?
        raise InvalidExchangeRateError.new("No rate found for #{to} in response")
      end

      Rate.new(
        date: date.to_date,
        from: from,
        to: to,
        rate: rate_value
      )
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      response = client.get("#{base_url}/#{api_key}/latest/#{from}")

      parsed = JSON.parse(response.body)

      if parsed["result"] == "error"
        raise Error.new("Failed to fetch exchange rates: #{parsed['error-type']}")
      end

      rate_value = parsed.dig("conversion_rates", to)

      if rate_value.nil?
        Rails.logger.warn("#{self.class.name} returned no rate for #{to}")
        return []
      end

      response_date = Date.parse(parsed["time_last_update_utc"])

      if response_date > end_date
        response_date = end_date
      end

      [ Rate.new(
        date: response_date,
        from: from,
        to: to,
        rate: rate_value
      ) ]
    end
  end

  private
    attr_reader :api_key

    def base_url
      ENV["EXCHANGE_RATE_API_URL"] || "https://v6.exchangerate-api.com/v6"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.5,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [ 429 ]
        })

        faraday.response :raise_error
      end
    end
end
