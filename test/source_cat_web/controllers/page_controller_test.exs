defmodule SourceCatWeb.PageControllerTest do
  use SourceCatWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ ~s(id="app")
    assert html =~ ~s(type="module")
    assert html =~ "/assets/index.js"
    assert html =~ "SourceCat"
  end
end
