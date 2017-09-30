defmodule ApiWeb.Vote do
  use Api.Web, :model

  alias ApiWeb.{Category, User}

  @attrs ~w(
    voter_identity
    category_id
    ballot
  )a

  schema "votes" do
    belongs_to(
      :voter,
      User,
      foreign_key: :voter_identity,
      references: :voter_identity,
      type: :string,
    )
    belongs_to :category, Category
    field :ballot, {:array, :binary_id}
    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @attrs)
    |> validate_required(@attrs)
    |> unique_constraint(:voter_identity_category_id)
    |> assoc_constraint(:voter)
    |> assoc_constraint(:category)
  end
end
