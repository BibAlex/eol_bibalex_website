class ContentPartnerUsers < ActiveRecord::Migration[5.1]
  def change
    # drop_table :content_partner_users

    create_table :content_partner_users do |t|
      t.references :user
      t.integer :content_partner_id
      t.timestamps null: false
    end
  end
end
