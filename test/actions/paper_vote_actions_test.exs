defmodule ApiWeb.PaperVoteActionsTest do
  use Api.DataCase

  alias ApiWeb.{CompetitionActions, PaperVoteActions, TeamActions, Team}

  setup do
    member = create_user()
    team = create_team(member)

    [member] = check_in_everyone()

    {
      :ok,
      %{
        category: create_category(),
        admin: create_admin(),
        member: member,
        team: team,
      },
    }
  end

  test "create", %{category: c, admin: a} do
    {:ok, _} = PaperVoteActions.create(c, a)
  end

  test "create after end", %{category: c, admin: a} do
    CompetitionActions.start_voting()
    CompetitionActions.end_voting()

    :already_ended = PaperVoteActions.create(c, a)
  end

  test "redeem", %{category: c, admin: a, member: m, team: t} do
    {:ok, p} = PaperVoteActions.create(c, a)
    [t] = make_teams_eligible([t])
    CompetitionActions.start_voting()

    {:ok, _} = PaperVoteActions.redeem(p, t, m, a)
  end

  test "redeem not twice", %{category: c, admin: a, member: m, team: t} do
    {:ok, p} = PaperVoteActions.create(c, a)
    [t] = make_teams_eligible([t])
    CompetitionActions.start_voting()

    {:ok, p} = PaperVoteActions.redeem(p, t, m, a)
    :already_redeemed = PaperVoteActions.redeem(p, t, m, a)
  end

  test "redeem not annulled", %{category: c, admin: a, member: m, team: t} do
    {:ok, p} = PaperVoteActions.create(c, a)
    [t] = make_teams_eligible([t])
    CompetitionActions.start_voting()

    {:ok, p} = PaperVoteActions.annul(p, a)
    :annulled = PaperVoteActions.redeem(p, t, m, a)
  end

  test "redeem not eligible", %{category: c, admin: a, member: m, team: t} do
    {:ok, p} = PaperVoteActions.create(c, a)
    # Notice I'm not making teams eligible
    CompetitionActions.start_voting()

    :team_not_eligible = PaperVoteActions.redeem(p, t, m, a)
  end

  test "redeem disqualified", %{category: c, admin: a, member: m, team: t} do
    {:ok, p} = PaperVoteActions.create(c, a)
    [t] = make_teams_eligible([t])
    CompetitionActions.start_voting()

    TeamActions.disqualify(t.id, a)
    t = Repo.get!(Team, t.id)

    :team_disqualified = PaperVoteActions.redeem(p, t, m, a)
  end

  test "redeem before start", %{category: c, admin: a, member: m, team: t} do
    {:ok, p} = PaperVoteActions.create(c, a)
    [t] = make_teams_eligible([t])

    :not_started = PaperVoteActions.redeem(p, t, m, a)
  end

  test "redeem after end", %{category: c, admin: a, member: m, team: t} do
    {:ok, p} = PaperVoteActions.create(c, a)
    [t] = make_teams_eligible([t])
    CompetitionActions.start_voting()
    CompetitionActions.end_voting()

    :already_ended = PaperVoteActions.redeem(p, t, m, a)
  end

  test "annul", %{category: c, admin: a} do
    {:ok, p} = PaperVoteActions.create(c, a)
    {:ok, _} = PaperVoteActions.annul(p, a)
  end

  test "annul after end", %{category: c, admin: a} do
    {:ok, p} = PaperVoteActions.create(c, a)

    CompetitionActions.start_voting()
    CompetitionActions.end_voting()

    :already_ended = PaperVoteActions.annul(p, a)
  end
end
