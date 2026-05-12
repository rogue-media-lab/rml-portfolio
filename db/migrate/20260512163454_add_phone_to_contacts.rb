class AddPhoneToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :phone, :string
  end
end
