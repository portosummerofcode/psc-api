defmodule Api.Admin.UserView do
  use Api.Web, :view

  alias Api.{TeamView, UserHelper}

  def render("index.json", %{users: users}) do
    %{data: render_many(users, __MODULE__, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, __MODULE__, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email,
      role: user.role,
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
      inserted_at: user.inserted_at,
      updated_at: user.updated_at,
      team: if Ecto.assoc_loaded?(user.team) do
        render_one(user.team, TeamView, "team_short.json") end,
      tshirt_size: user.tshirt_size,
    }
  end
end