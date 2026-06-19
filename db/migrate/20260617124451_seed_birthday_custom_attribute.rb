class SeedBirthdayCustomAttribute < ActiveRecord::Migration[7.1]
  # Idempotent: find_or_create_by so re-running is safe.
  def up
    Account.find_each do |account|
      CustomAttributeDefinition.find_or_create_by!(
        attribute_key:   'birthday',
        attribute_model: CustomAttributeDefinition.attribute_models[:contact_attribute],
        account_id:      account.id
      ) do |attr|
        attr.attribute_display_name = 'Aniversário'
        attr.attribute_display_type = CustomAttributeDefinition.attribute_display_types[:date]
      end
    end
  end

  def down
    CustomAttributeDefinition.where(attribute_key: 'birthday',
                                     attribute_model: CustomAttributeDefinition.attribute_models[:contact_attribute]).destroy_all
  end
end
