class EnableEnterpriseAndUnlockLimits < ActiveRecord::Migration[7.0]
  def up
    # Unlock Enterprise features
    InstallationConfig.where(name: 'INSTALLATION_PRICING_PLAN').first_or_create(locked: false).update(value: 'enterprise')

    # Unlock agent limits (1,000,000 licenses)
    InstallationConfig.where(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').first_or_create(locked: false).update(value: 1_000_000)
  end

  def down
    # Revert to Community if needed
    InstallationConfig.where(name: 'INSTALLATION_PRICING_PLAN').first_or_create(locked: false).update(value: 'community')
    InstallationConfig.where(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').first_or_create(locked: false).update(value: 0)
  end
end
