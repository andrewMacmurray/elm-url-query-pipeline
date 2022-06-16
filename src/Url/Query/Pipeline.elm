module Url.Query.Pipeline exposing
    ( into
    , required, optional, with, withDefault, hardcoded
    )

{-| Combine [elm/url](https://package.elm-lang.org/packages/elm/url/latest/Url-Parser-Query) Url Query param
parsers using a pipeline style -
think [elm-json-decode-pipeline](https://package.elm-lang.org/packages/NoRedInk/elm-json-decode-pipeline/latest/) but
for Url Query params:

    import Url.Parser as Parser exposing ((<?>), s, top)
    import Url.Parser.Query as Query
    import Url.Query.Pipeline as Pipeline

    type Route
        = Home (Maybe MyQuery)
        | AnotherRoute

    type alias MyQuery =
        { param1 : String
        , param2 : Maybe String
        , param3 : List Int
        }

    routeParser : Parser.Parser (Route -> a) a
    routeParser =
        Parser.oneOf
            [ Parser.map Home (top <?> pipelineQuery)
            , Parser.map AnotherRoute (s "another-route")
            ]

    pipelineQuery : Query.Parser (Maybe MyQuery)
    pipelineQuery =
        Pipeline.into MyQuery
            |> Pipeline.required (Query.string "param_1")
            |> Pipeline.optional (Query.string "param_2")
            |> Pipeline.with (Query.custom "param_3" toIntList)

    toIntList : List String -> List Int
    toIntList =
        List.filterMap String.toInt


# Start a Pipeline

@docs into


# Build a Pipeline

@docs required, optional, with, withDefault, hardcoded

-}

import Url.Parser.Query as Query


{-| Start off a pipeline

    type alias MyQuery =
        { param1 : String
        , param2 : Maybe String
        , param3 : Int
        }

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.into MyQuery
            |> Pipeline.required (Query.string "param_1")
            |> Pipeline.optional (Query.string "param_2")
            |> Pipeline.required (Query.int "param_3")

-}
into : a -> Query.Parser (Maybe a)
into a =
    Query.custom "" (\_ -> Just a)


{-| Combine a parser that must not be `Nothing`, if the parser returns `Nothing` the whole pipeline will return `Nothing`
-}
required :
    Query.Parser (Maybe a)
    -> Query.Parser (Maybe (a -> b))
    -> Query.Parser (Maybe b)
required a b =
    Query.map2 (\b_ a_ -> maybeAndMap a_ b_) b a


{-| Combine any parser as is: useful for Lists or Custom Types

    type alias MyQuery =
        { param1 : List String
        , param2 : Fruit
        }

    type Fruit
        = Apple
        | Pear

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.into MyQuery
            |> Pipeline.with (Query.custom "param_1" identity)
            |> Pipeline.with (Query.enum "param_2" fruitOptions |> Query.map (Maybe.withDefault Apple))

-}
with :
    Query.Parser a
    -> Query.Parser (Maybe (a -> b))
    -> Query.Parser (Maybe b)
with a b =
    Query.map2 (\b_ a_ -> maybeAndMap (Just a_) b_) b a


{-| Combine a parser that returns a `Maybe value`

    type alias MyQuery =
        { param1 : Maybe String
        , param2 : Maybe String
        }

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.into MyQuery
            |> Pipeline.optional (Query.string "param_1")
            |> Pipeline.optional (Query.string "param_2")

-}
optional :
    Query.Parser (Maybe a)
    -> Query.Parser (Maybe (Maybe a -> b))
    -> Query.Parser (Maybe b)
optional =
    with


{-| Apply a default value for a parser containing a Maybe

    type alias MyQuery =
        { param1 : String
        , param2 : Fruit
        }

    type Fruit
        = Apple
        | Pear

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.into MyQuery
            |> Pipeline.required (Query.string "param_1")
            |> Pipeline.withDefault (Query.enum "param_2" fruitOptions) Apple

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
        { param1 : String
        , param2 : Int
        }

    myQuery : Query.Parser (Maybe MyQuery)
    myQuery =
        Pipeline.into MyQuery
            |> Pipeline.required (Query.string "param_1")
            |> Pipeline.hardcoded 42

-}
hardcoded :
    a
    -> Query.Parser (Maybe (a -> b))
    -> Query.Parser (Maybe b)
hardcoded val b =
    required (into val) b


maybeAndMap : Maybe a -> Maybe (a -> b) -> Maybe b
maybeAndMap a b =
    Maybe.map2 (<|) b a
