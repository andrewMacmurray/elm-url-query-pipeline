module Url.Query.Pipeline exposing
    ( into
    , required, optional, with, withDefault, hardcoded
    )

{-|

@docs into

@docs required, optional, with, withDefault, hardcoded

-}

import Url.Parser.Query as Query


{-| -}
into : a -> Query.Parser (Maybe a)
into a =
    Query.custom "" (\_ -> Just a)


{-| -}
required : Query.Parser (Maybe a) -> Query.Parser (Maybe (a -> b)) -> Query.Parser (Maybe b)
required a b =
    Query.map2 (\b_ a_ -> maybeAndMap a_ b_) b a


{-| -}
with : Query.Parser a -> Query.Parser (Maybe (a -> b)) -> Query.Parser (Maybe b)
with a b =
    Query.map2 (\b_ a_ -> maybeAndMap (Just a_) b_) b a


{-| -}
optional : Query.Parser (Maybe a) -> Query.Parser (Maybe (Maybe a -> b)) -> Query.Parser (Maybe b)
optional =
    with


{-| -}
withDefault : Query.Parser (Maybe a) -> a -> Query.Parser (Maybe (a -> b)) -> Query.Parser (Maybe b)
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


{-| -}
hardcoded : a -> Query.Parser (Maybe (a -> b)) -> Query.Parser (Maybe b)
hardcoded val b =
    required (into val) b


maybeAndMap : Maybe a -> Maybe (a -> b) -> Maybe b
maybeAndMap a b =
    Maybe.map2 (<|) b a
