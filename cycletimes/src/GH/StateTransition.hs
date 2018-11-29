{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE RecordWildCards   #-}

module GH.StateTransition
(
  getStateTransitions
, getStateEvents
)
where

import           GH.Types
import qualified Data.List as L

-- | Given the creation time and a list of StateChange Events returns the
--   final StateTransition
--   PreCondition : The list of StateChange Events is assumed to be sorted
--   according to time
getStateTransitions :: TimeStamp -> [StateEvent] -> StateTransitions
getStateTransitions t stateChanges = go (STBacklog t) stateChanges
  where
    go :: StateTransitions -> [StateEvent] -> StateTransitions
    go finalState [] = finalState
    go currState (se:moreEvents) = go (transitionStep currState se) moreEvents


-- | The Core logic of StateTransition from one State to another
transitionStep :: StateTransitions -> StateEvent -> StateTransitions
transitionStep (STBacklog tb)        (StateEvent Backlog Backlog _)       = STBacklog tb
transitionStep (STBacklog tb)        (StateEvent Backlog InProgress tp)   = STInProgress tb tp
transitionStep (STBacklog tb)        (StateEvent Backlog InReview tr)     = STInReview tb tr tr
transitionStep (STInProgress tb tp)  (StateEvent InProgress Backlog _)    = STInProgress tb tp
transitionStep (STInProgress tb tp)  (StateEvent InProgress InProgress _) = STInProgress tb tp
transitionStep (STInProgress tb tp)  (StateEvent InProgress InReview tr)  = STInReview tb tp tr
transitionStep (STInProgress tb tp)  (StateEvent InProgress Done td)      = STDone tb tp td td
transitionStep (STInReview tb tp tr) (StateEvent InReview  Backlog _)     = STInReview tb tp tr
transitionStep (STInReview tb tp tr) (StateEvent InReview  InProgress _)  = STInReview tb tp tr
transitionStep (STInReview tb tp tr) (StateEvent InReview  InReview _)    = STInReview tb tp tr
transitionStep (STInReview tb tp tr) (StateEvent InReview  Done td)       = STDone tb tp tr td
transitionStep (STDone tb tp tr td)  (StateEvent Done InProgress _)       = STInReview tb tp tr
transitionStep (STDone tb tp tr td)  (StateEvent Done InReview _)         = STInReview tb tp tr
transitionStep (STDone tb tp tr td)  (StateEvent Done Done _)             = STDone tb tp tr td
transitionStep _ _ = STIllegalStateTransitions


-- | Given a list of GHIssueEvent and ZHIssueEvent returns a list of StateEvent by merging both
getStateEvents :: [GHIssueEvent] -> [ZHIssueEvent] -> [StateEvent]
getStateEvents ghs zhs = reverse $ _getStateEvents Nothing [] (L.sort $ (GHE <$> ghs) ++ (ZHE <$> zhs))

data IssueEvent = GHE GHIssueEvent | ZHE ZHIssueEvent
  deriving (Show, Eq)

instance Ord IssueEvent where
  compare ie1 ie2 = compare (getTime ie1) (getTime ie2)
    where
      getTime (ZHE (ZHEvtTransferState _ _ t)) = t
      getTime (GHE (GHEvtCloseEvent t))        = t
      getTime (GHE (GHEvtReOpenEvent t))       = t

_getStateEvents :: Maybe State -> [StateEvent] -> [IssueEvent]-> [StateEvent]
_getStateEvents oldState acc []  = acc
_getStateEvents oldState acc (ie:rest) = case ie of
  ZHE zhe ->  _getStateEvents oldState (fromZHEvent zhe : acc) rest
  GHE ghe -> case ghe of
    GHEvtCloseEvent ct -> let acc' = StateEvent (getLastState acc) Done ct : acc
                          in _getStateEvents (Just $ getLastState acc) acc' rest
    GHEvtReOpenEvent ct -> let newState = case oldState of
                                        Nothing -> StateEvent Backlog Backlog ct
                                        Just st -> StateEvent Done st ct
                           in _getStateEvents Nothing (newState : acc) rest


-- | convert a ZHIssueEvent to StateEvent
fromZHEvent :: ZHIssueEvent -> StateEvent
fromZHEvent (ZHEvtTransferState s1 s2 t) = StateEvent s1 s2 t

-- | from a list of StateEvent returns the most recent State
getLastState :: [StateEvent] -> State
getLastState ((StateEvent _ ls _) : _) = ls
getLastState _ = error "No Previous State Found"



