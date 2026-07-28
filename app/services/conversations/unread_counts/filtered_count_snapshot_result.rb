Conversations::UnreadCounts::FilteredCountSnapshotResult = Struct.new(:status, :payload, :version_mismatch, keyword_init: true) do
  def fresh? = status == :fresh
  def stale? = status == :stale
  def expired? = status == :expired
  def missing? = status == :missing
  def version_mismatch? = version_mismatch == true
end
