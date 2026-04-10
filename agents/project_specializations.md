This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `docker compose exec holter mix precommit` when you are done with all changes and fix any pending issues. **Never** run mix commands outside the container.
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps
- **CSS Strategy**: All UI styling must be implemented strictly using pure, modern Vanilla CSS with native features (like CSS Grid, Flexbox, and CSS Variables). Write dedicated, semantic CSS classes and attach them to the HTML elements.

<!-- holter:ui-start -->
## Holter UI & Component Architecture

### CSS Design System

All CSS tokens live in `assets/css/variables.css` in three layers:
1. **Primitivos** (`--prim-*`) — raw palette values. Never use directly in components.
2. **Semânticos** (`--color-*`) — purpose aliases. Always use these in components.
3. **Escala** (`--font-*`, `--space-*`, `--radius-*`, `--shadow-*`, `--transition-*`) — layout scale.

To restyle the entire app, edit only layers 1 and 2 in `variables.css`. No component CSS file needs to change.

All custom CSS classes use the `h-` prefix (e.g. `h-btn`, `h-input`, `h-table`). **Never** use Tailwind — it is not installed.

**Sharp corners**: all `--radius-*` tokens are `0`. Do not add rounded corners to new components unless explicitly requested.

### CSS File Structure

Every CSS file must have a single component owner. The structure mirrors the Elixir component tree:

```
assets/css/components/          ←→  lib/holter_web/components/
  back_link.css                       back_link.ex
  button.css                          button.ex
  empty_state.css                     empty_state.ex
  flash.css                           flash.ex
  header.css                          header.ex
  icon.css                            icon.ex
  input.css                           input.ex
  list.css                            list.ex
  modal.css                           modal.ex
  pagination.css                      pagination.ex
  table.css                           table.ex
  tooltip.css                         tooltip.ex
  monitoring/                         monitoring/
    dashboard_header.css                dashboard_header.ex
    health_badge.css                    health_badge.ex
    logs.css                            (logs live view)
    monitor_card.css                    monitor_card.ex
    monitor_form_fields.css             monitor_form_fields.ex
    daily_metrics_section.css           daily_metrics_section.ex
    sparkline.css                       sparkline.ex
    status_pill.css                     status_pill.ex
```

When creating a new component, always create its corresponding CSS file. When adding styles, always put them in the CSS file of the owning component.

### Component Structure

Components are split into individual files — there is **no monolithic `core_components.ex`**. Each component is its own module:

- **Global components** (`lib/holter_web/components/*.ex`) — usable anywhere. Automatically imported via `use HolterWeb, :html`.
- **Monitoring components** (`lib/holter_web/components/monitoring/*.ex`) — carry monitoring domain logic. Imported via `use HolterWeb, :monitoring_live_view`.

**Rules:**
- Each component lives in its own file. One file = one public component (private helpers are allowed in the same file).
- **Templates are thin**: `.html.heex` files only mount components and inject assigns. No visual logic, no inline styles, no conditionals about presentation.
- **Business logic lives in the domain**: thresholds, constants, and rules belong to the domain module (e.g. `Monitor.interval_min_seconds/0`, `DailyMetric.uptime_healthy?/1`), not in components.
- **Visual logic lives in components**: status colors, CSS class decisions, layout — these belong in the component, not the live view.

### Component Macros

Use the correct macro for each module type:

```elixir
# Individual component files
use HolterWeb, :component

# Monitoring live views (index, show, new, logs)
use HolterWeb, :monitoring_live_view

# Generic live views and non-monitoring HTML modules
use HolterWeb, :live_view
use HolterWeb, :html
```

### Icons

**Heroicons are NOT bundled.** The project does not include the `heroicons` dependency. `hero-*` CSS classes render as empty spans.

**Always use inline SVGs for icons.** Never reference `hero-*` class names. Never use `<.icon name="hero-*">`.

Example of the correct pattern:
```heex
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"
     fill="none" stroke="currentColor" stroke-width="2"
     stroke-linecap="round" stroke-linejoin="round">
  <path d="M19 12H5M12 5l-7 7 7 7" />
</svg>
```

### JS Transitions (show/hide)

Phoenix LiveView's `show/2` and `hide/2` helpers in `HolterWeb.Components.Icon` use custom `h-js-*` CSS classes (defined in `utilities.css`) — **not Tailwind classes**. Always use these helpers as-is. Do not add Tailwind class names to transition tuples.

### Form Inputs

Always use `<.input>` from `HolterWeb.Components.Input`. It is automatically imported via `html_helpers`. Never build raw `<input>` tags directly in templates for user-facing fields.

### i18n

`gettext/1` is a compile-time macro that requires string literals. **Never** pass a variable to `gettext/1`. Labels must stay as string literals inside component files. Domain modules must never call `gettext`.

### URL Encoding

When building query strings from maps, always sort before encoding to guarantee deterministic output:

```elixir
filters
|> Enum.sort_by(fn {k, _} -> to_string(k) end)
|> URI.encode_query()
```

### Atom Safety

Never use `String.to_atom/1` on external input (params, user data). Always use `String.to_existing_atom/1` with an explicit whitelist:

```elixir
@valid_keys ~w(status page page_size start_date end_date)
defp normalize_params(params) do
  for {k, v} <- params, k in @valid_keys, into: %{} do
    {String.to_existing_atom(k), v}
  end
end
```
<!-- holter:ui-end -->


<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option
- **Self-documenting variables over comments**: Prefer descriptive variable names over explanatory comments. For example, instead of `# Non-UTF8 binary data`, use `non_utf8_binary_body = <<...>>`. This is mandatory to comply with the project's strict **NoComments** rule.

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- holter:monitoring-testing-start -->
## Monitoring Engine — Testing Guidelines

### Monitor Changeset & Keyword Fields

- The `Monitor` changeset **only** accepts `raw_keyword_positive` and `raw_keyword_negative` (virtual string fields). Passing `keyword_positive: [...]` directly is **silently ignored** by `cast/3`.
- **Always** use the raw fields when creating monitors in tests:

      %{raw_keyword_positive: "success", raw_keyword_negative: "error"}

### Oban Worker Tests

- **Always** use `use Oban.Testing, repo: Holter.Repo` to unlock `perform_job/2`, `assert_enqueued/1`, and `refute_enqueued/1`.
- Use `perform_job(Worker, args)` — not `Worker.perform(%Oban.Job{args: args})` — to execute workers synchronously in the test process. This ensures Mox expectations set in the test process are visible to the worker.
- **Never** call `Oban.Testing.assert_enqueued/1` as a module-qualified function (it uses a nil repo). **Always** use the imported macro version injected by `use Oban.Testing`.

### MonitorClient HTTP Behaviour

- The `MonitorClient.HTTP` implementation **must** set `retry: false` on all `Req` calls. Req's default retry policy retries `5xx` responses, which masks the original status code and causes flaky test assertions.
- The `:method` option passed to `Req` **must be an atom** (e.g. `:GET`), never a lowercase string (`"get"`). Passing a string causes the wrong HTTP method to be sent, resulting in 404s from local test servers.

### Integration Tests with DummyService

- `Holter.Test.DummyService` is a local `Plug.Router` + `Bandit` server running on the port configured in `config :holter, :dummy_port`.
- Use simple **alphanumeric `call_id`s** (e.g. `"check1"`). The `Plug.Router` `:param` binding **does not support hyphens or underscores** mid-token — they break route matching silently.
- Use `DummyService.enqueue(call_id, status: ..., body: ...)` to register FIFO responses. Each `GET /probe/:call_id` consumes one entry from the queue. This allows testing response sequences without coupling the URL path to domain IDs.
- **Always** call `DummyService.reset()` in `setup` to prevent cross-test state pollution.
- Extract the `call_id` as a module attribute (`@call_id`) to avoid repetition across setup and test body.

### Architecture: Engine vs Worker Separation

- Business logic (status evaluation, keyword validation, incident lifecycle, log creation) lives in `Holter.Monitoring.Engine`.
- `Holter.Monitoring.Workers.HTTPCheck` is a thin Oban wrapper: it only fetches the monitor, resolves the HTTP client, executes the request, and delegates to the Engine.
- Test the Engine directly (`EngineTest`) with plain `%Req.Response{}` structs — no network, no Oban required.
- Test the Worker (`HTTPCheckTest`) only to verify the client injection and delegation chain using Mox.
- Test the full stack (`IntegrationTest`) with `DummyService` as a real HTTP server to validate the network path.

### One Assert Per Test

Each `test` block **must contain exactly one `assert`**. This makes failures immediately pinpoint the broken behaviour without scanning multiple assertions.

Move the action (the operation under test) into the `setup` block using a strict match (`:ok = action()`), not `assert`. Each resulting `test` block then contains a single `assert` for one specific outcome.

ExUnit **does not support nested `describe` blocks**. Model stateful sequences as flat, independent `describe` blocks where each `setup` builds the required state from scratch:

```elixir
describe "when monitor goes down" do
  setup %{monitor: monitor, job_args: job_args} do
    DummyService.enqueue("check1", status: 500, body: "Error")
    :ok = perform_job(HTTPCheck, job_args)      # action — not an assert
  end

  test "sets health_status to :down", %{monitor: monitor} do
    assert Monitoring.get_monitor!(monitor.id).health_status == :down
  end

  test "opens a downtime incident", %{monitor: monitor} do
    assert Monitoring.get_open_incident(monitor.id)
  end

  test "sets root_cause from HTTP status", %{monitor: monitor} do
    assert %{root_cause: "HTTP Error: 500"} = Monitoring.get_open_incident(monitor.id)
  end
end

describe "when monitor recovers after downtime" do
  setup %{monitor: monitor, job_args: job_args} do
    DummyService.enqueue("check1", status: 500, body: "Error")
    :ok = perform_job(HTTPCheck, job_args)
    incident = Monitoring.get_open_incident(monitor.id)
    DummyService.enqueue("check1", status: 200, body: "OK")
    :ok = perform_job(HTTPCheck, job_args)
    %{incident: incident}
  end

  test "sets health_status to :up", %{monitor: monitor} do
    assert Monitoring.get_monitor!(monitor.id).health_status == :up
  end

  test "closes the incident", %{monitor: monitor} do
    assert is_nil(Monitoring.get_open_incident(monitor.id))
  end
end
```
<!-- holter:monitoring-testing-end -->


<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied
<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use regular semantic CSS classes:

      <div id="tasks" phx-update="stream">
        <div class="empty-state-message">No tasks yet</div>
        <div :for={{id, task} <- @stream.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->