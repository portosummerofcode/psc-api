defmodule Api.UserView do
  use Api.Web, :view

  alias Api.{TeamMemberView, UserHelper}

  def render("index.json", %{users: users}) do
    %{data: render_many(users, __MODULE__, "user_short.json")}
  end

  def render("user_short.json", %{user: user}) do
    %{
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      gravatar_hash: UserHelper.gravatar_hash(user),
      display_name: UserHelper.display_name(user),
      tshirt_size: user.tshirt_size,
    }
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, __MODULE__, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      gravatar_hash: UserHelper.gravatar_hash(user),
      display_name: UserHelper.display_name(user),
      birthday: user.birthday,
      bio: user.bio,
      github_handle: user.github_handle,
      twitter_handle: user.twitter_handle,
      linkedin_url: user.linkedin_url,
      employment_status: user.employment_status,
      college: user.college,
      company: user.company,
      team: if user.team do
        render_one(user.team, TeamMemberView, "member_team_short.json", as: :membership)
      end,
      tshirt_size: user.tshirt_size,
    }
  end
end
