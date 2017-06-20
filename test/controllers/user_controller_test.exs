defmodule Api.UserControllerTest do
  use Api.ConnCase

  alias Api.User

  @valid_attrs %{
    email: "johndoe@example.com",
    first_name: "john",
    last_name: "doe",
    password: "thisisapassword"
  }
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, user_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    %{id: id} = create_user
    create_team(%{user_id: id, name: "awesome team"})

    user = Repo.get!(User, id)
    |> Repo.preload(:team)

    conn = get conn, user_path(conn, :show, user)
    
    assert json_response(conn, 200)["data"] == %{
      "id" => user.id,
      "first_name" => user.first_name,
      "last_name" => user.last_name,
      "display_name" => "#{user.first_name} #{user.last_name}",
      "gravatar_hash" => "fd876f8cd6a58277fc664d47ea10ad19",
      "birthday" => user.birthday,
      "employment_status" => user.employment_status,
      "college" => user.college,
      "company" => user.company,
      "github_handle" => user.github_handle,
      "twitter_handle" => user.twitter_handle,
      "linkedin_url" => user.linkedin_url,
      "bio" => user.bio,
      "team" => %{
        "id" => user.team.id,
        "name" => user.team.name
      }
    }
  end

  test "display name from email if there's no first and last name", %{conn: conn} do
    user = create_user(%{first_name: nil, last_name: nil, email: "johndoe@example.com", password: "password"})

    conn = get conn, user_path(conn, :show, user)

    assert json_response(conn, 200)["data"]["display_name"] == "johndoe"
  end

  test "display_name from first name if there's no last name", %{conn: conn} do
    user = create_user(%{first_name: "john", last_name: nil, email: "johndoe@example.com", password: "password"})

    conn = get conn, user_path(conn, :show, user)

    assert json_response(conn, 200)["data"]["display_name"] == "john"
  end

  test "display_name from first and last name if they're present", %{conn: conn} do
    user = create_user(%{first_name: "john", last_name: "doe", email: "johndoe@example.com", password: "password"})

    conn = get conn, user_path(conn, :show, user)

    assert json_response(conn, 200)["data"]["display_name"] == "john doe"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, user_path(conn, :show, "11111111-1111-1111-1111-111111111111")
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @valid_attrs
    assert json_response(conn, 201)["data"]["user"]["id"]
    assert Repo.get_by(User, email: "johndoe@example.com")
  end

  test "doesn't create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    user = Repo.insert! %User{}
    conn = put conn, user_path(conn, :update, user), user: @valid_attrs
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(User, email: "johndoe@example.com")
  end

  test "doesn't update chosen resource and renders errors when data is invalid", %{conn: conn} do
    user = Repo.insert! %User{}
    conn = put conn, user_path(conn, :update, user), user: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    user = Repo.insert! %User{}
    conn = delete conn, user_path(conn, :delete, user)
    assert response(conn, 204)
    refute Repo.get(User, user.id)
  end
end
