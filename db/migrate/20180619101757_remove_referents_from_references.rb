class RemoveReferentsFromReferences < ActiveRecord::Migration[5.1]
  def change
    remove_reference :references, :referents, index: true, foreign_key: true
  end
end
