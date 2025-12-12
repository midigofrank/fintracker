class ProviderApiUsage < ApplicationRecord
  validates :provider_name, :concept, presence: true
  validates :provider_name, uniqueness: { scope: :concept }

  def update_usage!(used:, limit:, utilization:)
    update!(
      requests_used: used,
      requests_limit: limit,
      utilization_percentage: utilization,
      last_checked_at: Time.current
    )
  end

  def approaching_limit?(threshold_percentage = 80)
    utilization_percentage >= threshold_percentage
  end

  def self.track_usage_for(provider:, concept:)
    return unless provider.respond_to?(:usage)

    usage_response = provider.usage
    return unless usage_response.success?

    usage_data = usage_response.data
    record = find_or_initialize_by(
      provider_name: provider.class.name.demodulize.underscore,
      concept: concept.to_s
    )

    record.update_usage!(
      used: usage_data.used,
      limit: usage_data.limit,
      utilization: usage_data.utilization
    )

    if record.approaching_limit?
      Rails.logger.warn("Provider #{record.provider_name} for #{record.concept} is approaching API limit: #{record.utilization_percentage}% used")
    end

    record
  end
end
