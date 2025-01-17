defmodule AccentTest.Movement.Builders.RevisionUncorrectAll do
  @moduledoc false
  use Accent.RepoCase, async: true

  alias Accent.Language
  alias Accent.ProjectCreator
  alias Accent.Repo
  alias Accent.Translation
  alias Accent.User
  alias Movement.Builders.RevisionUncorrectAll, as: RevisionUncorrectAllBuilder

  @user %User{email: "test@test.com"}

  setup do
    user = Repo.insert!(@user)
    language = Repo.insert!(%Language{name: "English", slug: Ecto.UUID.generate()})

    {:ok, project} =
      ProjectCreator.create(params: %{main_color: "#f00", name: "My project", language_id: language.id}, user: user)

    revision = project |> Repo.preload(:revisions) |> Map.get(:revisions) |> hd()

    {:ok, [revision: revision]}
  end

  test "builder fetch translations and uncorrect conflict", %{revision: revision} do
    translation = Repo.insert!(%Translation{key: "a", proposed_text: "A", conflicted: false, revision_id: revision.id})

    context =
      %Movement.Context{}
      |> Movement.Context.assign(:revision, revision)
      |> RevisionUncorrectAllBuilder.build()

    translation_ids = Enum.map(context.assigns[:translations], &Map.get(&1, :id))
    operations = Enum.map(context.operations, &Map.get(&1, :action))

    assert translation_ids === [translation.id]
    assert operations === ["uncorrect_conflict"]
  end

  test "builder fetch translations and ignore conflicted translation", %{revision: revision} do
    Repo.insert!(%Translation{key: "a", proposed_text: "A", conflicted: true, revision_id: revision.id})

    context =
      %Movement.Context{}
      |> Movement.Context.assign(:revision, revision)
      |> RevisionUncorrectAllBuilder.build()

    translation_ids = Enum.map(context.assigns[:translations], &Map.get(&1, :id))

    assert translation_ids === []
    assert context.operations === []
  end
end
