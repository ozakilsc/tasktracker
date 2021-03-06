class CreateTags < ActiveRecord::Migration
  def up
    rename_column :projects, :tags, :old_tags
    rename_column :stickies, :tags, :old_tags

    create_table :tags do |t|
      t.string :name
      t.text :description
      t.string :color, default: "#dddddd", null: false
      t.integer :project_id
      t.integer :user_id
      t.boolean :deleted, default: false, null: false

      t.timestamps
    end

    add_index :tags, :project_id
    add_index :tags, :user_id
  end

  def down
    drop_table :tags
    rename_column :projects, :old_tags, :tags
    rename_column :stickies, :old_tags, :tags
  end
end
