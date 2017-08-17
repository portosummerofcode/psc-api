defimpl Phoenix.Param, for: Api.Workshop do
  def to_param(%{id: slug}) do
    "#{slug}"
  end
end

defmodule Api.Workshop do
  use Api.Web, :model

  @valid_attrs ~w(name slug summary description speaker participant_limit
    year speaker_image banner_image)
  @required_attrs ~w(name slug)a
  @derive {Phoenix.Param, key: :slug}

  schema "workshops" do
    field :name, :string
    field :slug, :string
    field :summary, :string
    field :description, :string
    field :speaker, :string
    field :participant_limit, :integer
    field :year, :integer
    field :speaker_image, :string
    field :banner_image, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @valid_attrs)
    |> validate_required(@required_attrs)
  end
end
