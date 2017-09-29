defmodule ApiWeb.Admin.UserView do
  use Api.Web, :view

  alias ApiWeb.{MembershipView, WorkshopView, UserView}
  import Api.Accounts.User, only: [display_name: 1, gravatar_hash: 1]

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
      gravatar_hash: gravatar_hash(user),
      display_name: display_name(user),
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
      team: if user.team do
        render_one(user.team, MembershipView, "member_team_short.json", as: :membership)
      end,
      tshirt_size: user.tshirt_size,
      workshops: if Ecto.assoc_loaded?(user.workshops) do
        render_many(user.workshops, WorkshopView, "workshop_short.json")
      end,
      checked_in: user.checked_in,
    }
  end

  def render("user_short.json", %{user: user}) do
    Map.merge(
      render_one(user, UserView, "user_short.json"),
      %{
        email: user.email,
      }
    )
  end
end
