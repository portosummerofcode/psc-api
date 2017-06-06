defmodule Api.TeamTest do
  use Api.ModelCase

  alias Api.Team

  @valid_attrs %{name: "awesome team"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Team.changeset(%Team{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Team.changeset(%Team{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset with no attributes" do
    changeset = Team.changeset(%Team{})
    refute changeset.valid?
  end
end