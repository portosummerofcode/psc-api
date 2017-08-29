defmodule Api.InviteActions do
  use Api.Web, :action

  @slack_token Application.get_env(:api, :slack_token)
  @slack_error_codes %{
    already_invited: "was already invited",
    already_in_team: "is already in the team",
    missing_scope: "couldn't be invited at this time",
    invalid_email: "isn't valid",
    channel_not_found: "couldn't join inexistent channel",
    user_disabled: "account has been deactivated",
    sent_recently: "was invited recently"
  }
  @team_user_limit Application.get_env(:api, :team_user_limit)
  @http Application.get_env(:api, :http_lib)

  alias Api.{Invite, Repo, Mailer, Email, TeamMember, UserActions, User}
  alias Guardian.{Plug}

  def for_current_user(conn) do
    current_user = Plug.current_resource(conn)

    Invite
    |> where(invitee_id: ^current_user.id)
    |> Repo.all
    |> Repo.preload([:host, :invitee, :team])
  end

  def get(id) do
    Repo.get!(Invite, id)
    |> Repo.preload([:host, :team, :invitee])
  end

  def create(conn, invite_params) do
    user = Plug.current_resource(conn)
    |> UserActions.add_current_team

    if user.team do
      create_if_vacant(user, invite_params)
    else
      {:usr_no_team}
    end
  end

  def accept(id) do
    case Repo.get(Invite, id) do
      nil -> {:error, "Invite not found"}
      invite -> create_membership(invite)
    end
  end

  def delete(id) do
    invite = Repo.get!(Invite, id)
    Repo.delete!(invite)
  end

  def invite_to_slack(email) do
    base_url = "https://portosummerofcode.slack.com/api/users.admin.invite"
    params = "token=#{@slack_token}&email=#{email}"
    url = base_url <> "?" <> params
    headers = %{"Content-Type" => "application/x-www-form-urlencoded"}

    with {:ok, response} <- @http.post(url, "", headers), do: process_slack_invite(response)
  end

  defp create_if_vacant(user, invite_params) do
    # Since user.team returns a membership instead of the actual team,
    # we need to send user.team.team
    invites_count = Enum.count(user.team.team.invites)
    members_count = Enum.count(user.team.team.members)
    team_users = invites_count + members_count

    if team_users < @team_user_limit do
      changeset = Invite.changeset(%Invite{
        host_id: user.id,
        team_id: user.team.team_id,
      }, invite_params)

      process_email(changeset, user)

      Repo.insert(changeset)
    else
      {:usr_limit_reached}
    end   
  end

  defp process_email(changeset, host) do
    cond do
      Map.has_key?(changeset.changes, :email) -> send_invite_email(changeset, host)
      Map.has_key?(changeset.changes, :invitee_id) -> send_notification_email(changeset, host)
      true -> nil
    end
  end

  defp create_membership(invite) do
    changeset = TeamMember.changeset(%TeamMember{},
      %{user_id: invite.invitee_id, team_id: invite.team_id})

    case Repo.insert(changeset) do
      {:ok, _} -> Repo.delete(invite)
      {:error, _} -> {:error, "Unable to create membership"}
    end   
  end

  defp send_invite_email(changeset, host) do
    Map.get(changeset.changes, :email)
    |> Email.invite_email(host)
    |> Mailer.deliver_later
  end

  defp send_notification_email(changeset, host) do
    Repo.get(User, Map.get(changeset.changes, :invitee_id))
    |> Email.invite_notification_email(host)
    |> Mailer.deliver_later
  end

  defp process_slack_invite(response) do
    case Poison.decode! response.body do
      %{"ok" => true} -> {:ok, true}
      %{"ok" => false, "error" => error} ->
        error_message = Map.get(@slack_error_codes, String.to_atom(error))
        {:error, %{email: [error_message]}}
    end
  end
end
