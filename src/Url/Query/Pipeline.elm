module Url.Query.Pipeline exposing
    ( succeed
    , required, optional, with, withDefault, hardcoded
    )

{-| Combine [elm/url](https://package.elm-lang.org/packages/elm/url/latest/Url-Parser-Query) Url Query param
parsers using a pipeline style -
think [elm-json-decode-pipeline](https://package.elm-lang.org/packages/NoRedInk/elm-json-decode-pipeline/latest/) but
for Url Query params:

    import Url exposing (Url)
    import Url.Parser as Parser exposing ((<?>), s, top)
    import Url.Parser.Query as Query
    import Url.Query.Pipeline as Pipeline

    type Route
        = Home (Maybe MyQuery)
        | AnotherRoute

    type alias MyQuery =
        { one : String
        , two : Maybe String
        , three : List Int
        }

    query : Query.Parser (Maybe MyQuery)
    query =
        Pipeline.succeed MyQuery
            |> Pipeline.required (Query.string "one")
            |> Pipeline.optional (Query.string "two")
            |> Pipeline.with (Query.custom "three" (List.filterMap String.toInt))

    routes : Parser.Parser (Route -> a) a
    routes =
        Parser.oneOf
            [ Parser.map Home (top <?> query)
            , Parser.map AnotherRoute (s "another-route")
            ]

    fromString : String -> Maybe Route
    fromString =
        Url.fromString >> Maybe.andThen (Parser.parse routes)

Some examples from above:

    fromString "http://example/another-route" == Just AnotherRoute

    fromString "http://example?one=hello&two=world&three=1&three=2"
        == Just
            (Home
                (Just
                    { one = "hello"
                    , two = Just "world"
                    , three = [ 1, 2 ]
                    }
                )
            )

    -- required param "one" is missing
    fromString "http://example?two=world&three=1"
        == Just (Home Nothing)

The examples below use the function `parse`

    parse : Query.Parser (Maybe MyQuery) -> String -> Maybe MyQuery


## Why is the output `Maybe MyQuery`?

`elm/url`'s [Query Parsers](https://package.elm-lang.org/packages/elm/url/latest/Url-Parser-Query) all return `Maybe a`.

The `Pipeline` functions is also `Maybe a` to maintain compatibility with `elm/url`.


# Start a Pipeline

@docs succeed


# Build a Pipeline

@docs required, optional, with, withDefault, hardcoded

-}

import Url.Parser.Query as Query


{-| Start off a pipeline

    type alias MyQuery =
        { one : String
        , two : Maybe String
        , three : Int
        }

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.succeed MyQuery
            |> Pipeline.required (Query.string "one")
            |> Pipeline.optional (Query.string "two")
            |> Pipeline.required (Query.int "three")

Examples:

    parse myQuery "one=one&two=two&three=3"
        == Just
            { one = "one"
            , two = Just "two"
            , three = 3
            }

    parse myQuery "one=one&three=3"
        == Just
            { one = "one"
            , two = Nothing
            , three = 3
            }

-}
succeed : a -> Query.Parser (Maybe a)
succeed a =
    Query.custom "" (\_ -> Just a)


{-| Combine a parser that must not be `Nothing`, if the parser returns `Nothing` the whole pipeline will return `Nothing`

    type alias MyQuery =
        { one : String
        , two : Maybe String
        }

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.succeed MyQuery
            |> Pipeline.required (Query.string "one")
            |> Pipeline.optional (Query.string "two")

Examples:

    parse myQuery "one=one&two=two"
        == Just { one = "one", two = Just "two" }

    parse myQuery "one=one"
        == Just { one = "one", two = Nothing }

    -- missing required param
    parse myQuery "two=two"
        == Nothing

-}
required :
    Query.Parser (Maybe a)
    -> Query.Parser (Maybe (a -> b))
    -> Query.Parser (Maybe b)
required a b =
    Query.map2 (\b_ a_ -> maybeAndMap a_ b_) b a


{-| Combine a parser that returns a `Maybe value`

    type alias MyQuery =
        { one : Maybe String
        , two : Maybe String
        }

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.succeed MyQuery
            |> Pipeline.optional (Query.string "one")
            |> Pipeline.optional (Query.string "two")

Examples:

    parse myQuery "one=one"
        == Just { one = Just "one", two = Nothing }

    parse myQuery "two=two"
        == Just { one = Nothing "one", two = Just "two" }

    parse myQuery ""
        == Just { one = Nothing, two = Nothing }

-}
optional :
    Query.Parser (Maybe a)
    -> Query.Parser (Maybe (Maybe a -> b))
    -> Query.Parser (Maybe b)
optional =
    with


{-| Combine any parser as is: useful for Lists or Custom Types

    type alias MyQuery =
        { one : List String
        , two : Fruit
        }

    type Fruit
        = Apple
        | Pear

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.succeed MyQuery
            |> Pipeline.with (Query.custom "one" identity)
            |> Pipeline.with (Query.enum "two" fruitOptions |> Query.map (Maybe.withDefault Apple))

Examples:

    parse myQuery "one=a&one=b&two=pear"
        == Just { one = [ "a", "b" ], two = Pear }

    parse myQuery "two=apple"
        == Just { one = [], two = Apple }

-}
with :
    Query.Parser a
    -> Query.Parser (Maybe (a -> b))
    -> Query.Parser (Maybe b)
with a b =
    Query.map2 (\b_ a_ -> maybeAndMap (Just a_) b_) b a


{-| Apply a default value for a parser containing a Maybe

    type alias MyQuery =
        { one : String
        , two : Fruit
        }

    type Fruit
        = Apple
        | Pear

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.succeed MyQuery
            |> Pipeline.required (Query.string "one")
            |> Pipeline.withDefault (Query.enum "two" fruitOptions) Apple

Examples:

    parse myQuery "one=one&two=pear"
        == Just { one = "one", two = Pear }

    parse myQuery "one=one"
        == Just { one = "one", two = Apple }

-}
withDefault :
    Query.Parser (Maybe a)
    -> a
    -> Query.Parser (Maybe (a -> b))
    -> Query.Parser (Maybe b)
withDefault a default b =
    Query.map2
        (\b_ a_ ->
            case a_ of
                Just v ->
                    maybeAndMap (Just v) b_

                Nothing ->
                    maybeAndMap (Just default) b_
        )
        b
        a


{-| Apply a hardcoded value

    type alias MyQuery =
        { one : String
        , two : Int
        }

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.succeed MyQuery
            |> Pipeline.required (Query.string "one")
            |> Pipeline.hardcoded 42

Examples:

    parse myQuery "one=one"
        == Just { one = "one", two = 42 }

-}
hardcoded :
    a
    -> Query.Parser (Maybe (a -> b))
    -> Query.Parser (Maybe b)
hardcoded val b =
    required (succeed val) b


maybeAndMap : Maybe a -> Maybe (a -> b) -> Maybe b
maybeAndMap a b =
    Maybe.map2 (<|) b a
