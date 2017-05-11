defmodule Api.User do
  @moduledoc """
    TODO: Write.
  """

  use Api.Web, :model
  @derive {Poison.Encoder, only: [:id, :email, :first_name, :last_name]}

  alias Comeonin.Bcrypt

  @valid_attrs ~w(email first_name last_name password birthday employment_status college
                  company github_handle twitter_handle bio)

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :password_hash, :string
    field :birthday, :date
    field :employment_status, :string
    field :college, :string
    field :company, :string
    field :github_handle, :string
    field :twitter_handle, :string
    field :bio, :string

    timestamps()

    # Virtual fields
    field :password, :string, virtual: true

    # Relationships
    has_one :project, Api.Project
  end

  @doc "Builds a changeset based on the `struct` and `params`."
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @valid_attrs)
    |> validate_required(~w(email)a)
    |> validate_length(:email, min: 1, max: 255)
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
  end

  def registration_changeset(struct, params \\ %{}) do
    struct
    |> changeset(params)
    |> validate_required(~w(password)a)
    |> validate_length(:password, min: 6)
    |> hash_password
  end

  defp hash_password(%{valid?: false} = changeset), do: changeset
  defp hash_password(%{valid?: true} = changeset) do
    hashed_password =
      changeset
      |> get_field(:password)
      |> Bcrypt.hashpwsalt()

    changeset
    |> put_change(:password_hash, hashed_password)
  end
end
