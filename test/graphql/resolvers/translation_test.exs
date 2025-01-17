defmodule AccentTest.GraphQL.Resolvers.Translation do
  @moduledoc false
  use Accent.RepoCase, async: true

  alias Accent.Document
  alias Accent.GraphQL.Resolvers.Translation, as: Resolver
  alias Accent.Language
  alias Accent.Project
  alias Accent.Repo
  alias Accent.Revision
  alias Accent.Translation
  alias Accent.User
  alias Accent.Version

  defmodule PlugConn do
    @moduledoc false
    defstruct [:assigns]
  end

  @user %User{email: "test@test.com"}

  setup do
    user = Repo.insert!(@user)
    french_language = Repo.insert!(%Language{name: "french"})
    project = Repo.insert!(%Project{main_color: "#f00", name: "My project"})

    revision = Repo.insert!(%Revision{language_id: french_language.id, project_id: project.id, master: true})
    context = %{context: %{conn: %PlugConn{assigns: %{current_user: user}}}}

    {:ok, [user: user, project: project, revision: revision, context: context]}
  end

  test "key", %{revision: revision, context: context} do
    {:ok, key} = Resolver.key(%Translation{revision_id: revision.id, key: "Foo", proposed_text: "bar"}, %{}, context)
    assert key === "Foo"

    {:ok, key} =
      Resolver.key(%Translation{revision_id: revision.id, key: "Foo.__KEY__1.Bar", proposed_text: "bar"}, %{}, context)

    assert key === "Foo.[1].Bar"
  end

  test "correct", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    {:ok, result} = Resolver.correct(translation, %{text: "Corrected text"}, context)

    assert get_in(result, [:errors]) == nil
    assert get_in(result, [:translation, Access.key(:id)]) == translation.id
    assert get_in(Repo.all(Translation), [Access.all(), Access.key(:corrected_text)]) == ["Corrected text"]
    assert get_in(Repo.all(Translation), [Access.all(), Access.key(:conflicted)]) == [false]
  end

  test "uncorrect", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: false,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    {:ok, result} = Resolver.uncorrect(translation, %{text: "baz"}, context)

    assert get_in(result, [:errors]) == nil
    assert get_in(result, [:translation, Access.key(:id)]) == translation.id
    assert get_in(Repo.all(Translation), [Access.all(), Access.key(:corrected_text)]) == ["baz"]
    assert get_in(Repo.all(Translation), [Access.all(), Access.key(:conflicted_text)]) == ["bar"]
    assert get_in(Repo.all(Translation), [Access.all(), Access.key(:conflicted)]) == [true]
  end

  test "update", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    {:ok, result} = Resolver.update(translation, %{text: "Updated text"}, context)

    assert get_in(result, [:errors]) == nil
    assert get_in(result, [:translation, Access.key(:id)]) == translation.id
    assert get_in(Repo.all(Translation), [Access.all(), Access.key(:corrected_text)]) == ["Updated text"]
    assert get_in(Repo.all(Translation), [Access.all(), Access.key(:conflicted)]) == [true]
  end

  test "show project", %{project: project, revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    {:ok, result} = Resolver.show_project(project, %{id: translation.id}, context)

    assert get_in(result, [Access.key(:id)]) == translation.id
  end

  test "show project unknown id", %{project: project, context: context} do
    {:ok, result} = Resolver.show_project(project, %{id: Ecto.UUID.generate()}, context)

    assert is_nil(result)
  end

  test "show project unknown project", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    {:ok, result} = Resolver.show_project(%Project{id: Ecto.UUID.generate()}, %{id: translation.id}, context)

    assert is_nil(result)
  end

  test "list revision", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    Repo.insert!(%Translation{
      revision_id: revision.id,
      conflicted: true,
      key: "hidden",
      corrected_text: "bar",
      proposed_text: "bar",
      locked: true
    })

    {:ok, result} = Resolver.list_revision(revision, %{}, context)

    assert get_in(result, [:entries, Access.all(), Access.key(:id)]) == [translation.id]
  end

  test "list revision with query", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    Repo.insert!(%Translation{
      revision_id: revision.id,
      conflicted: true,
      key: "aux",
      corrected_text: "foo",
      proposed_text: "foo"
    })

    {:ok, result} = Resolver.list_revision(revision, %{query: "bar"}, context)

    assert get_in(result, [:entries, Access.all(), Access.key(:id)]) == [translation.id]
  end

  test "list revision with document", %{project: project, revision: revision, context: context} do
    document = Repo.insert!(%Document{path: "bar", format: "json", project_id: project.id})
    other_document = Repo.insert!(%Document{path: "foo", format: "json", project_id: project.id})

    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar",
        document_id: document.id
      })

    Repo.insert!(%Translation{
      revision_id: revision.id,
      conflicted: true,
      key: "ok",
      corrected_text: "foo",
      proposed_text: "foo",
      document_id: other_document.id
    })

    {:ok, result} = Resolver.list_revision(revision, %{document: document.id}, context)

    assert get_in(result, [:entries, Access.all(), Access.key(:id)]) == [translation.id]
  end

  test "list revision with order", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "aaaaaa",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    other_translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "bbbbb",
        corrected_text: "foo",
        proposed_text: "foo"
      })

    {:ok, result} = Resolver.list_revision(revision, %{order: "-key"}, context)

    assert get_in(result, [:entries, Access.all(), Access.key(:id)]) == [other_translation.id, translation.id]
  end

  test "list revision with conflicted", %{revision: revision, context: context} do
    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: false,
        key: "bar",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    Repo.insert!(%Translation{
      revision_id: revision.id,
      conflicted: true,
      key: "foo",
      corrected_text: "foo",
      proposed_text: "foo"
    })

    {:ok, result} = Resolver.list_revision(revision, %{is_conflicted: false}, context)

    assert get_in(result, [:entries, Access.all(), Access.key(:id)]) == [translation.id]
  end

  test "list revision with version", %{project: project, revision: revision, user: user, context: context} do
    version = Repo.insert!(%Version{name: "bar", tag: "v1.0", project_id: project.id, user_id: user.id})
    other_version = Repo.insert!(%Version{name: "foo", tag: "v2.0", project_id: project.id, user_id: user.id})

    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar",
        version_id: version.id
      })

    Repo.insert!(%Translation{
      revision_id: revision.id,
      conflicted: true,
      key: "ok",
      corrected_text: "foo",
      proposed_text: "foo",
      version_id: other_version.id
    })

    {:ok, result} = Resolver.list_revision(revision, %{version: version.id}, context)

    assert get_in(result, [:entries, Access.all(), Access.key(:id)]) == [translation.id]
  end

  test "related translations", %{project: project, revision: revision, context: context} do
    english_language = Repo.insert!(%Language{name: "english"})

    other_revision =
      Repo.insert!(%Revision{
        language_id: english_language.id,
        project_id: project.id,
        master: false,
        master_revision_id: revision.id
      })

    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    other_translation =
      Repo.insert!(%Translation{
        revision_id: other_revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "foo",
        proposed_text: "foo"
      })

    {:ok, result} = Resolver.related_translations(translation, %{}, context)

    assert get_in(result, [Access.all(), Access.key(:id)]) == [other_translation.id]
  end

  test "master translation", %{project: project, revision: revision, context: context} do
    english_language = Repo.insert!(%Language{name: "english"})

    other_revision =
      Repo.insert!(%Revision{
        language_id: english_language.id,
        project_id: project.id,
        master: false,
        master_revision_id: revision.id
      })

    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    other_translation =
      Repo.insert!(%Translation{
        revision_id: other_revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "foo",
        proposed_text: "foo"
      })

    {:ok, result} = Resolver.master_translation(other_translation, %{}, context)

    assert result.id == translation.id
  end

  test "master translation as master", %{project: project, revision: revision, context: context} do
    english_language = Repo.insert!(%Language{name: "english"})

    other_revision =
      Repo.insert!(%Revision{
        language_id: english_language.id,
        project_id: project.id,
        master: false,
        master_revision_id: revision.id
      })

    translation =
      Repo.insert!(%Translation{
        revision_id: revision.id,
        conflicted: true,
        key: "ok",
        corrected_text: "bar",
        proposed_text: "bar"
      })

    Repo.insert!(%Translation{
      revision_id: other_revision.id,
      conflicted: true,
      key: "ok",
      corrected_text: "foo",
      proposed_text: "foo"
    })

    {:ok, result} = Resolver.master_translation(translation, %{}, context)

    assert result.id == translation.id
  end
end
