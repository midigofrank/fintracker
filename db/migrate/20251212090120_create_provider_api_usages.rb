class CreateProviderApiUsages < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_api_usages, id: :uuid do |t|
      t.string :provider_name, null: false
      t.string :concept, null: false
      t.integer :requests_used
      t.integer :requests_limit
      t.decimal :utilization_percentage, precision: 5, scale: 2
      t.datetime :last_checked_at

      t.timestamps
    end

    add_index :provider_api_usages, [ :provider_name, :concept ], unique: true
  end
end
