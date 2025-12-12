class ImportExchangeRatesJob < ApplicationJob
  queue_as :scheduled

  def perform
    return if Rails.env.development?

    importer = MarketDataImporter.new(mode: :full, clear_cache: false)
    importer.import_exchange_rates
  end
end
