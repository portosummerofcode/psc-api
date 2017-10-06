defmodule Api.Teams do
  import Ecto.Query, warn: false

  @slack_token Application.get_env(:api, :slack_token)
  @team_user_limit Application.get_env(:api, :team_user_limit)
  @http Application.get_env(:api, :http_lib)

  alias Api.{Mailer, Repo}
  alias Api.Accounts
  alias Api.Accounts.User
  alias Api.Competitions
  alias Api.Competitions.Category
  alias Api.Teams.{Invite, Membership, Team}
  alias Api.Integrations.Github
  alias Api.Notifications.Emails
  alias Ecto.{Changeset, Multi}

  def current_user_invites(current_user) do
    Invite
    |> where(invitee_id: ^current_user.id)
    |> Repo.all
    |> Repo.preload([:host, :invitee, :team])
  end

  def get_invite(id) do
    Repo.get!(Invite, id)
    |> Repo.preload([:host, :team, :invitee])
  end

  def create_invite(current_user, invite_params) do
    user = Accounts.preload_user_data(current_user)

    if user.team do
      create_invite_if_vacant(user, invite_params)
    else
      :user_without_team
    end
  end

  def accept_invite(id) do
    case Repo.get(Invite, id) do
      nil -> :invite_not_found
      invite -> create_membership(invite)
    end
  end

  def delete_invite(id) do
    invite = Repo.get!(Invite, id)
    Repo.delete!(invite)
  end

  def invite_to_slack(email) do
    base_url = "https://portosummerofcode.slack.com/api/users.admin.invite"
    params = URI.encode_query(%{token: @slack_token, email: email})
    url = base_url <> "?" <> params
    headers = %{"Content-Type" => "application/x-www-form-urlencoded"}

    with {:ok, response} <- @http.post(url, "", headers), do: process_slack_invite(response)
  end

  defp create_invite_if_vacant(user, invite_params) do
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
      |> maybe_associate_user()
      |> process_email(user)

      Repo.insert(changeset)
    else
      :team_user_limit
    end
  end

  def update_invite(invite, params) do
    Invite.changeset(invite, params) |> Repo.update
  end

  defp maybe_associate_user(changeset) do
    if Map.has_key?(changeset.changes, :email) do
      case Repo.get_by(User, email: Map.get(changeset.changes, :email)) do
        nil -> changeset
        user ->
          Changeset.delete_change(changeset, :email)
          |> Changeset.put_change(:invitee_id, user.id)
      end
    else
      changeset
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
    case Competitions.voting_status do
      :started -> :already_started
      _ ->
        changeset = Membership.changeset(
          %Membership{},
          %{user_id: invite.invitee_id, team_id: invite.team_id}
        )
        case Repo.insert(changeset) do
          {:ok, _} -> Repo.delete(invite)
          {:error, _} -> {:error, "Unable to create membership"}
        end
    end
  end

  defp send_invite_email(changeset, host) do
    Map.get(changeset.changes, :email)
    |> Emails.invite_email(host)
    |> Mailer.deliver_later

    changeset
  end

  defp send_notification_email(changeset, host) do
    Repo.get(User, Map.get(changeset.changes, :invitee_id))
    |> Emails.invite_notification_email(host)
    |> Mailer.deliver_later

    changeset
  end

  defp process_slack_invite(response) do
    case Poison.decode! response.body do
      %{"ok" => true} -> {:ok, true}
      %{"ok" => false, "error" => error} ->
        message = message(String.to_atom(error))
        {:error, %Ecto.Changeset{
          valid?: false,
          types: %{email: :string},
          errors: [email: {message, []}],
        }}
    end
  end

  defp message(:already_invited), do: "was already invited"
  defp message(:already_in_team), do: "is already in the team"
  defp message(:missing_scope), do: "couldn't be invited at this time"
  defp message(:invalid_email), do: "isn't valid"
  defp message(:channel_not_found), do: "couldn't join inexistent channel"
  defp message(:user_disabled), do: "account has been deactivated"
  defp message(:sent_recently), do: "was invited recently"

  def list_teams do
    Repo.all(Team)
    |> Repo.preload([members: [:user], invites: [:host, :invitee, :team]])
  end

  def get_team(id) do
    Repo.get!(Team, id)
    |> Repo.preload([members: [:user], invites: [:host, :invitee, :team]])
  end

  def create_team(current_user, team_params) do
    changeset = Team.changeset(%Team{}, team_params, Repo)

    case Repo.insert(changeset) do
      {:ok, team} ->
        Repo.insert! %Membership{user_id: current_user.id, team_id: team.id, role: "owner"}

        team = team
        |> Repo.preload([:invites, members: [:user]])

        {:ok, team}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update_team(current_user, id, team_params) do
    team = get_team(id)

    if is_team_member?(team, current_user) do
      Team.changeset(team, team_params, Repo)
      |> email_if_applying(team)
      |> Repo.update
    else
      {:unauthorized, :unauthorized}
    end
  end

  def delete_team(current_user, id) do
    team = Repo.get!(Team, id)

    case is_team_member?(team, current_user) do
      true -> {Repo.delete!(team)}
      false -> {:unauthorized, :unauthorized}
    end
  end

  def remove_membership(current_user, team_id, user_id) do
    if Competitions.voting_status == :started do
      throw :already_started
    end

    team = Repo.get!(Team, team_id)
    user = Repo.get(User, user_id) || throw :user_not_found

    if !is_team_member?(team, current_user) do
      throw {:unauthorized, :unauthorized}
    end

    if team.applied do
      throw :team_locked
    end

    case Repo.delete_all(from(
        t in Membership,
        where: t.user_id == ^user.id and t.team_id == ^team.id
    )) do
      {1, _} -> :ok
      {0, _} -> :membership_not_found
    end
  catch
    e -> e
  end

  def update_any_team(id, team_params) do
    team = get_team(id)

    team_params = case Competitions.voting_status do
      :started ->
        {_, team_params} = Map.pop(team_params, :eligible)
        {_, team_params} = Map.pop(team_params, "eligible")
        team_params
      _ ->
        team_params
    end

    Team.admin_changeset(team, team_params, Repo)
    |> email_if_applying(team)
    |> Repo.update
  end

  def delete_any_team(id) do
    Repo.get!(Team, id) |> Repo.delete!
  end

  def remove_any_membership(team_id, user_id) do
    if Competitions.voting_status == :started do
        throw :already_started
    end
    user = Repo.get(User, user_id) || throw :user_not_found
    case Repo.delete_all(from(
        t in Membership,
        where: t.user_id == ^user.id and t.team_id == ^team_id
    )) do
      {1, _} ->
        {:ok}
      {0, _} -> :membership_not_found
    end
  catch
    e -> e
  end

  def shuffle_tie_breakers do
    teams = Repo.all(from t in Team)

    multi = Multi.new

    # I can't update the tie breakers to their intended value on just one pass.
    # Consider the case where you have two teams, A and B, with tie breakers 1
    # and 2, respectively. If we decide that team A gets the tie breaker 2,
    # on the fisrt update, the BD will complain that both A and B have the tie
    # breaker 1. In order to get around that, we make them all negative first,
    # and only assign the new tie breakers after that. Since we know the new
    # tie breakers won't ever be negative, this gets rid of all conflicts.
    multi =
      Enum.reduce(
        teams,
        multi,
        fn team, multi ->
          Multi.update(
            multi,
            "#{team.id} to negative",
            Changeset.change(team, tie_breaker: -1 * team.tie_breaker)
          )
        end
      )

    multi =
      Enum.reduce(
        Enum.zip([
          teams,
          (1..Enum.count(teams)) |> Enum.shuffle
        ]),
        multi,
        fn {team, new_tb}, multi ->
          Multi.update(
            multi,
            "#{team.id} to shuffled",
            team
            |> Changeset.change()
            |> Changeset.force_change(:tie_breaker, new_tb)
          )
        end
      )

    Repo.transaction(multi)
  end

  def create_repo(id) do
    team = Repo.get!(Team, id)

    case Github.create_repo(team) do
      {:ok, repo} ->
        __MODULE__.update_any_team(id, %{repo: repo})
        :ok
      {:error, error} -> error
    end
  end

  def add_users_to_repo(id) do
     team = Repo.get!(Team, id)
     |> Repo.preload(members: :user)

    Enum.each(team.members, fn(membership) ->
      Github.add_collaborator(team.repo, membership.user.github_handle)
    end)
  end

  defp is_team_member?(team, user) do
    team = team
    |> Repo.preload([:members])

    Enum.any?(team.members, fn(member) ->
      member.user_id == user.id
    end)
  end

  defp email_if_applying(changeset, team) do
    applied_change = Map.has_key?(changeset.changes, :applied)
    applied_true = Map.get(changeset.changes, :applied) == true

    if applied_change and applied_true do
      Enum.map(team.members, fn(member) ->
        Emails.joined_hackathon_email(member.user, team) |> Mailer.deliver_later
      end)
    end

    changeset
  end

  def disqualify_team(team_id, admin) do
    from(
      t in Team,
      where: t.id == ^team_id,
      where: is_nil(t.disqualified_at),
      update: [set: [
        disqualified_at: ^(DateTime.utc_now),
        disqualified_by_id: ^(admin.id),
      ]]
    )
    |> Repo.update_all([])
  end

  def assign_missing_preferences do
    cats = Repo.all(Category) |> Enum.map(&(&1.name))

    Repo.all(from(t in Team, where: is_nil(t.prize_preference)))
    |> Enum.map(fn t ->
      t
      |> Changeset.change(prize_preference: cats |> Enum.shuffle)
      |> Repo.update!
    end)
  end
end
