require "test_helper"

class Provider::ExchangeRateApiTest < ActiveSupport::TestCase
  setup do
    @subject = Provider::ExchangeRateApi.new("test_api_key")
  end

  test "responds to healthy?" do
    assert_respond_to @subject, :healthy?
  end

  test "responds to usage" do
    assert_respond_to @subject, :usage
  end

  test "fetches single exchange rate" do
    VCR.use_cassette("#{vcr_key_prefix}/exchange_rate") do
      response = @subject.fetch_exchange_rate(
        from: "USD",
        to: "GBP",
        date: Date.parse("01.01.2024")
      )

      rate = response.data

      assert_equal "USD", rate.from
      assert_equal "GBP", rate.to
      assert rate.date.is_a?(Date)
      assert_in_delta 0.78, rate.rate, 0.01
    end
  end

  test "fetches latest exchange rate for historical range" do
    VCR.use_cassette("#{vcr_key_prefix}/exchange_rates") do
      response = @subject.fetch_exchange_rates(
        from: "USD", to: "GBP", start_date: Date.parse("01.01.2024"), end_date: Date.parse("31.07.2024")
      )

      assert_equal 1, response.data.count
      assert response.data.first.date.is_a?(Date)
      assert_equal "USD", response.data.first.from
      assert_equal "GBP", response.data.first.to
      assert_in_delta 0.78, response.data.first.rate, 0.01
    end
  end

  private
    def vcr_key_prefix
      @subject.class.name.demodulize.underscore
    end
end
