defmodule Holter.Credo.Check.Design.RequireBodyguardPermit do
  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Boundary modules (controllers and LiveViews under `lib/holter_web/`) that
      call a mutating context function must also call `authorize/3` (or
      `Bodyguard.permit/4`) in the same `def`/`defp` body. The web layer is
      the single source of truth for "who can do what"; every mutation flows
      through that gate.

      Mutating calls are detected by namespace + function-name prefix:
      a call into `Holter.{Monitoring,Delivery,Identity}.*` whose function
      name starts with one of `create_`, `update_`, `delete_`, `mark_`,
      `regenerate_`, `revoke_`, `apply_staged_`, `resend_`, `dispatch_test_`,
      `enqueue_` or `recalculate_`.

      Example violation:
          def delete(conn, %{"id" => id}) do
            with {:ok, monitor} <- Monitoring.get_monitor(id),
                 {:ok, _} <- Monitoring.delete_monitor(monitor) do
              send_resp(conn, :no_content, "")
            end
          end

      Correct pattern:
          def delete(conn, %{"id" => id}) do
            actor = conn.assigns.current_user

            with {:ok, monitor} <- Monitoring.get_monitor(id),
                 :ok <- authorize(actor, :delete, monitor),
                 {:ok, _} <- Monitoring.delete_monitor(monitor) do
              send_resp(conn, :no_content, "")
            end
          end

      Workers and other non-boundary code (anything outside `lib/holter_web/`)
      are exempt — they run as the trusted system and the upstream caller
      that enqueued them is responsible for the permit.
      """
    ]

  @mutation_prefixes ~w(
    create_
    update_
    delete_
    mark_
    regenerate_
    revoke_
    apply_staged_
    resend_
    dispatch_test_
    enqueue_
    recalculate_
  )

  @guarded_namespaces [:Monitoring, :Delivery, :Identity]

  # Functions where the actor acts on its own identity (login, logout,
  # registration, password reset, locale preference). There is no third
  # party to authorize against — the user IS the resource.
  @self_action_exemptions [
    :create_session_token,
    :delete_session_token,
    :update_user_preferences,
    :register_user,
    :verify_email,
    :request_password_reset,
    :reset_password
  ]

  def run(source_file, params \\ []) do
    if boundary_file?(source_file) do
      issue_meta = IssueMeta.for(source_file, params)
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp boundary_file?(%{filename: filename}) do
    String.contains?(filename, "/holter_web/")
  end

  defp traverse({def_type, meta, [name_args, [do: body]]} = ast, issues, issue_meta)
       when def_type in [:def, :defp] do
    name = extract_fn_name(name_args)

    cond do
      not mutation_call?(body) ->
        {ast, issues}

      authorize_call?(body) ->
        {ast, issues}

      true ->
        {ast, [make_issue(issue_meta, name, meta[:line]) | issues]}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp extract_fn_name({:when, _, [head | _]}), do: extract_fn_name(head)
  defp extract_fn_name({name, _, _}), do: name
  defp extract_fn_name(_), do: nil

  defp mutation_call?(body) do
    any_match?(body, fn
      {{:., _, [{:__aliases__, _, aliases}, fn_name]}, _, _args} when is_atom(fn_name) ->
        guarded_namespace?(aliases) and mutation_prefix?(fn_name) and
          fn_name not in @self_action_exemptions

      _ ->
        false
    end)
  end

  defp authorize_call?(body) do
    any_match?(body, fn
      {:authorize, _, args} when is_list(args) ->
        true

      {{:., _, [{:__aliases__, _, aliases}, :permit]}, _, _args} ->
        List.last(aliases) == :Bodyguard

      _ ->
        false
    end)
  end

  defp any_match?(body, predicate) do
    {_ast, found?} =
      Macro.prewalk(body, false, fn node, acc ->
        cond do
          acc -> {node, true}
          predicate.(node) -> {node, true}
          true -> {node, false}
        end
      end)

    found?
  end

  defp guarded_namespace?(aliases) do
    Enum.any?(aliases, &(&1 in @guarded_namespaces))
  end

  defp mutation_prefix?(fn_name) do
    str = Atom.to_string(fn_name)
    Enum.any?(@mutation_prefixes, &String.starts_with?(str, &1))
  end

  defp make_issue(issue_meta, fn_name, line_no) do
    format_issue(issue_meta,
      message:
        "Boundary function '#{fn_name}' calls a mutating context fn without authorize/3 " <>
          "or Bodyguard.permit/4 in the same body. Add an authorize/3 call to gate it.",
      trigger: to_string(fn_name),
      line_no: line_no
    )
  end
end
