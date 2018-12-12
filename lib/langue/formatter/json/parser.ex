defmodule Langue.Formatter.Json.Parser do
  @behaviour Langue.Formatter.Parser

  alias Langue.Utils.{NestedParserHelper, Placeholders}

  def parse(%{render: render}) do
    entries = parse_json(render)

    %Langue.Formatter.ParserResult{entries: entries}
  end

  def parse_json(render) do
    render
    |> :jiffy.decode()
    |> elem(0)
    |> NestedParserHelper.parse()
    |> Placeholders.parse(Langue.Formatter.Json.placeholder_regex())
  end
end
