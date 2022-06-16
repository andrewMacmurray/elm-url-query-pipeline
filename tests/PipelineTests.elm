module PipelineTests exposing (tests)

import Dict
import Expect
import Test exposing (Test, describe, test)
import Url
import Url.Parser as Parser
import Url.Parser.Query as Query
import Url.Query.Pipeline as Pipeline


tests : Test
tests =
    describe "Query Pipeline"
        [ describe "optional and required"
            [ test "handles required and optional arguments" <|
                \_ ->
                    parse
                        { params = "foo=a&bar=b"
                        , parser =
                            Pipeline.succeed Two
                                |> Pipeline.required (Query.string "foo")
                                |> Pipeline.optional (Query.string "bar")
                        }
                        |> Expect.equal
                            (Just
                                { first = "a"
                                , second = Just "b"
                                }
                            )
            , test "returns Nothing if required param missing" <|
                \_ ->
                    parse
                        { params = "bar=b"
                        , parser =
                            Pipeline.succeed Two
                                |> Pipeline.required (Query.string "foo")
                                |> Pipeline.optional (Query.string "bar")
                        }
                        |> Expect.equal Nothing
            , test "returns default Nothing for optional argument" <|
                \_ ->
                    parse
                        { params = "foo=a"
                        , parser =
                            Pipeline.succeed Two
                                |> Pipeline.required (Query.string "foo")
                                |> Pipeline.optional (Query.string "bar")
                        }
                        |> Expect.equal
                            (Just
                                { first = "a"
                                , second = Nothing
                                }
                            )
            ]
        , describe "with and withDefault"
            [ test "works with lists" <|
                \_ ->
                    parse
                        { params = "tags[]=dogs&tags[]=cats&ids[]=4&ids[]=5"
                        , parser =
                            Pipeline.succeed Two
                                |> Pipeline.with (Query.custom "tags[]" identity)
                                |> Pipeline.with (Query.custom "ids[]" (List.filterMap String.toInt))
                        }
                        |> Expect.equal
                            (Just
                                { first = [ "dogs", "cats" ]
                                , second = [ 4, 5 ]
                                }
                            )
            , test "works for any parser with a default value" <|
                \_ ->
                    parse
                        { params = "fruit=unknown"
                        , parser =
                            Pipeline.succeed One
                                |> Pipeline.with (fruitQueryWithDefault Orange)
                        }
                        |> Expect.equal
                            (Just
                                { first = Orange
                                }
                            )
            , test "uses default value when query parser returns Nothing" <|
                \_ ->
                    parse
                        { params = "fruit=unknown"
                        , parser =
                            Pipeline.succeed Two
                                |> Pipeline.withDefault fruitQuery Apple
                                |> Pipeline.withDefault (Query.int "quantity") 1
                        }
                        |> Expect.equal
                            (Just
                                { first = Apple
                                , second = 1
                                }
                            )
            ]
        , describe "hardcoded"
            [ test "allows hardcoded values" <|
                \_ ->
                    parse
                        { params = "foo=foo"
                        , parser =
                            Pipeline.succeed Two
                                |> Pipeline.hardcoded 42
                                |> Pipeline.required (Query.string "foo")
                        }
                        |> Expect.equal
                            (Just
                                { first = 42
                                , second = "foo"
                                }
                            )
            ]
        ]


fruitQueryWithDefault : Fruit -> Query.Parser Fruit
fruitQueryWithDefault fruit =
    fruitQuery |> Query.map (Maybe.withDefault fruit)


fruitQuery : Query.Parser (Maybe Fruit)
fruitQuery =
    Query.enum "fruit"
        (Dict.fromList
            [ ( "apple", Apple )
            , ( "banana", Banana )
            , ( "orange", Orange )
            ]
        )


type Fruit
    = Apple
    | Banana
    | Orange


type alias One a =
    { first : a
    }


type alias Two a b =
    { first : a
    , second : b
    }


parse : { params : String, parser : Query.Parser (Maybe a) } -> Maybe a
parse options =
    ("http://localhost:8080/?" ++ options.params)
        |> Url.fromString
        |> Maybe.andThen (Parser.parse (Parser.query options.parser))
        |> Maybe.andThen identity
