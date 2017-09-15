defmodule ApiWeb.ErrorViewTest do
  use ApiWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View
  alias ApiWeb.{ErrorView}

  test "renders 404.json" do
    assert render(ErrorView, "404.json", []) ==
           %{errors: %{detail: "Page not found"}}
  end

  test "render 500.json" do
    assert render(ErrorView, "500.json", []) ==
           %{errors: %{detail: "Internal server error"}}
  end

  test "render any other" do
    assert render(ErrorView, "505.json", []) ==
           %{errors: %{detail: "Internal server error"}}
  end
end
