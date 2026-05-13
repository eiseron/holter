defimpl FunWithFlags.Actor, for: Holter.Identity.Models.User do
  def id(%{id: id}), do: "user:#{id}"
end
