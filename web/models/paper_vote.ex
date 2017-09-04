defmodule Api.PaperVote do
  @moduledoc """
    TODO: Write.
  """

  use Api.Web, :model

  alias Api.{Crypto, Team, Category, User}

  @required_attrs [
    :hmac_secret,
  ]

  @valid_attrs @required_attrs ++ [
    :redeemed_at,
    :annulled_at,
  ]

  schema "paper_votes" do
    field :hmac_secret, :string
    belongs_to :category, Category
    belongs_to :created_by, User

    field :redeemed_at, :utc_datetime
    belongs_to :redeeming_admin, User
    belongs_to :redeeming_member, User
    belongs_to :team, Team

    field :annulled_at, :utc_datetime
    belongs_to :annulled_by, User

    timestamps()
  end

  def hmac(paper_vote) do
    Crypto.hmac(paper_vote.hmac_secret, paper_vote.id)
  end

  def creation_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @valid_attrs)
    |> put_assoc(:category, params.category)
    |> put_assoc(:created_by, params.created_by)
    |> validate_required(@required_attrs)
  end

  def redemption_changeset(struct, params \\ %{}) do
    creation_changeset(struct, params)
    |> put_assoc(:redeeming_admin, params.redeeming_admin)
    |> put_assoc(:redeeming_member, params.redeeming_member)
    |> put_assoc(:team, params.team)
  end

  def annulment_changeset(struct, params \\ %{}) do
    creation_changeset(struct, params)
    |> put_assoc(:annulled_by, params.annulled_by)
  end
end