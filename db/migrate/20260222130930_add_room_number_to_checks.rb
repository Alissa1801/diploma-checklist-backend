class AddRoomNumberToChecks < ActiveRecord::Migration[8.1]
  def change
    add_column :checks, :room_number, :string
  end
end
