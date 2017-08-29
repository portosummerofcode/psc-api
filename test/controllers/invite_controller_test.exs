defmodule Api.InviteControllerTest do
  use Api.ConnCase
  use Bamboo.Test, shared: true

  alias Api.{Invite, Email, TeamMember}

  setup %{conn: conn} do
    user = create_user
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(user)

    {:ok, %{
      user: user,
      jwt: jwt,
      claims: full_claims,
      conn: put_req_header(conn, "content-type", "application/json")
    }}
  end

  test "lists all invites", %{conn: conn, jwt: jwt, user: user} do
    host = create_user(%{
      email: "example@email.com",
      first_name: "Jane",
      last_name: "doe",
      password: "thisisapassword"
    })
    team = create_team(host)
    invite = create_invite(%{host_id: host.id, team_id: team.id, invitee_id: user.id})

    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> get(invite_path(conn, :index))

    assert json_response(conn, 200)["data"] == [%{
      "description" => invite.description,
      "email" => invite.email,
      "host" => %{
        "display_name" => "#{host.first_name} #{host.last_name}",
        "first_name" => host.first_name,
        "gravatar_hash" => "8455938a1db5c475a87d76edacb6284e",
        "id" => host.id,
        "last_name" => host.last_name,
        "tshirt_size" => host.tshirt_size
      },
      "id" => invite.id,
      "invitee" => %{
        "display_name" => "#{user.first_name} #{user.last_name}",
        "first_name" => user.first_name,
        "gravatar_hash" => "fd876f8cd6a58277fc664d47ea10ad19",
        "id" => user.id,
        "last_name" => user.last_name,
        "tshirt_size" => user.tshirt_size
      },
      "open" => invite.open,
      "team" => %{
        "id" => team.id,
        "name" => team.name
      }
    }]
  end

  test "shows chosen invite", %{conn: conn, user: user} do
    team = create_team(user)
    invite = create_invite(%{host_id: user.id, team_id: team.id})

    conn = get conn, invite_path(conn, :show, invite)
    assert json_response(conn, 200)["data"] == %{
      "id" => invite.id,
      "description" => invite.description,
      "team" => %{
        "id" => team.id,
        "name" => team.name
      },
      "host" => %{
        "id" => user.id,
        "first_name" => user.first_name,
        "last_name" => user.last_name,
        "display_name" => "#{user.first_name} #{user.last_name}",
        "gravatar_hash" => "fd876f8cd6a58277fc664d47ea10ad19",
        "tshirt_size" => nil,
      },
      "invitee" => nil,
      "open" => false,
      "email" => nil,
    }
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, invite_path(conn, :show, "11111111-1111-1111-1111-111111111111")
    end
  end

  test "creates invite when data and request are valid", %{conn: conn, jwt: jwt, user: user} do
    invitee = create_user(%{
      email: "example@email.com",
      first_name: "Jane",
      last_name: "doe",
      password: "thisisapassword"
    })
    create_team(user)

    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> post(invite_path(conn, :create, invite: %{invitee_id: invitee.id}))

    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get(Invite, json_response(conn, 201)["data"]["id"])
  end

  test "creates invite and sends email", %{conn: conn, jwt: jwt, user: user} do
    create_team(user)

    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> post(invite_path(conn, :create, invite: %{email: "user@example.org"}))

    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get(Invite, json_response(conn, 201)["data"]["id"])
    assert_delivered_email Email.invite_email("user@example.org", user)
  end

  test "creates invite and sends email notification", %{conn: conn, jwt: jwt, user: user} do
    create_team(user)
    random_user = create_user(%{
      email: "user@email.com",
      first_name: "Jane",
      last_name: "Doe",
      password: "thisisapassword"
    })

    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> post(invite_path(conn, :create, invite: %{invitee_id: random_user.id}))

    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get(Invite, json_response(conn, 201)["data"]["id"])
    assert_delivered_email Email.invite_notification_email(random_user, user)
  end

  test "doesn't create invite when data is invalid", %{conn: conn, jwt: jwt} do
    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> post(invite_path(conn, :create), invite: %{})

    assert json_response(conn, 422)["errors"] == "Couldn't make changes to your team"
  end

  test "doesn't create invite if user limit is reached", %{conn: conn, jwt: jwt, user: user} do
    team = create_team(user)

    member1 = create_user(%{email: "user1@example.com", password: "thisisapassword"})
    member2 = create_user(%{email: "user2@example.com", password: "thisisapassword"})

    Repo.insert! %TeamMember{user_id: member1.id, team_id: team.id}
    Repo.insert! %TeamMember{user_id: member2.id, team_id: team.id}
    create_invite(%{host_id: user.id, team_id: team.id})

    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> post(invite_path(conn, :create, invite: %{email: "user3@example.org"}))

    assert json_response(conn, 422)["errors"] == "Team user limit reached"
  end

  test "membership is created when invitation is accepted", %{conn: conn, jwt: jwt, user: user} do
    host = create_user(%{
      email: "example@email.com",
      first_name: "Jane",
      last_name: "doe",
      password: "thisisapassword"
    })
    team = create_team(host)
    invite = create_invite(%{host_id: host.id, team_id: team.id, invitee_id: user.id})

    conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> put(invite_path(conn, :accept, invite))

    team = Repo.preload(team, :members)

    assert Enum.count(team.members) == 2
  end

  test "membership isn't created if invitation doesn't exist", %{conn: conn, jwt: jwt} do
    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> put(invite_path(conn, :accept, %Invite{id: Ecto.UUID.generate()}))

    assert json_response(conn, 422)["errors"] == "Invite not found"
  end

  test "deletes chosen resource", %{conn: conn, jwt: jwt} do
    invite = Repo.insert! %Invite{}

    conn = conn
    |> put_req_header("authorization", "Bearer #{jwt}")
    |> delete(invite_path(conn, :delete, invite))
    
    assert response(conn, 204)
    refute Repo.get(Invite, invite.id)
  end

  test "invite to slack works", %{conn: conn} do
    conn = conn
    |> post(invite_path(conn, :invite_to_slack, %{email: "valid@example.com"}))

    assert response(conn, 201)
  end

  test "invite to slack returns errors properly", %{conn: conn} do
    conn = conn
    |> post(invite_path(conn, :invite_to_slack, %{email: "error@example.com"}))

    assert response(conn, 422)
  end 
end
