module Thompson

import Core
import NFA
import Data.List

%default total

public export
data BaseStates = StartState | AcceptState

public export
Eq BaseStates where
  StartState  == StartState   = True
  AcceptState == AcceptState  = True
  _           == _            = False

--- helper functions
public export
mapStates : (s -> s') -> List (s, Routine) -> List (s', Routine)
mapStates f states = map (bimap f id) states

public export
mapRoutine : (Routine -> Routine) -> List (s, Routine) -> List (s, Routine)
mapRoutine f xs = map (bimap id f) xs

public export
addEndRoutine : (isEnd : state -> Bool) -> Routine -> List (state, Routine) -> List (state, Routine)
addEndRoutine isEnd routine [] = []
addEndRoutine isEnd routine (x :: xs) =
  if (isEnd (fst x))
  then (fst x, snd x ++ routine) :: (addEndRoutine isEnd routine xs)
  else x :: (addEndRoutine isEnd routine xs)

public export
addEndTransition  : (state -> Bool) 
                  -> List (state', Routine) 
                  -> (state -> state') 
                  -> List (state, Routine) 
                  -> List (state', Routine)

addEndTransition isEnd newTrans conv [] = []
addEndTransition isEnd newTrans conv ((st, r) :: xs) =
  if (isEnd st)
  then (mapRoutine (r ++) newTrans) ++ (addEndTransition isEnd newTrans conv xs)
  else (conv st, r) :: (addEndTransition isEnd newTrans conv xs)

--- functions for predicate
public export
acceptingPred : BaseStates -> Bool
acceptingPred AcceptState = True
acceptingPred StartState  = False

public export
nextPred  : (f : Char -> Bool) -> (st: BaseStates) -> (c: Char)
          -> List (BaseStates, Routine)
nextPred f StartState c = if (f c) then [(AcceptState, [EmitLast])] else []
nextPred _ AcceptState _ = []

--- functions for Group
public export
groupTransform : (sm : SM) -> List (sm.State, Routine) -> List (sm.State, Routine)
groupTransform sm states = 
  addEndRoutine sm.accepting [EmitString] (mapRoutine (const []) states)

--- functions for Alternation
public export
acceptingAlt : (sm1, sm2 : SM) -> Either sm1.State sm2.State -> Bool
acceptingAlt sm1 sm2 (Left s) = sm1.accepting s
acceptingAlt sm1 sm2 (Right s) = sm2.accepting s

public export
startAlt : (sm1, sm2 : SM) -> List(Either sm1.State sm2.State, Routine)
startAlt sm1 sm2 = mapStates Left (addEndRoutine sm1.accepting [EmitLeft] sm1.start) 
                ++ mapStates Right (addEndRoutine sm2.accepting [EmitRight] sm2.start)

public export
nextAlt   : (sm1, sm2 : SM) 
          -> Either sm1.State sm2.State 
          -> Char 
          -> List(Either sm1.State sm2.State, Routine)

nextAlt sm1 sm2 (Left st) c = 
  mapStates Left (addEndRoutine sm1.accepting [EmitLeft] (sm1.next st c))
nextAlt sm1 sm2 (Right st) c = 
  mapStates Right (addEndRoutine sm2.accepting [EmitRight] (sm2.next st c))

--- functions for Concatenation
public export
acceptingConcat : (sm1, sm2 : SM) -> Either sm1.State sm2.State -> Bool
acceptingConcat sm1 sm2 (Left _) = False
acceptingConcat sm1 sm2 (Right st) = sm2.accepting st

public export
startConcat : (sm1, sm2 : SM) -> List (Either sm1.State sm2.State, Routine)
startConcat sm1 sm2 = 
  addEndRoutine 
    (acceptingConcat sm1 sm2) 
    [EmitPair] 
    (addEndTransition 
      sm1.accepting 
      (mapStates Right sm2.start) 
      Left 
      sm1.start)

public export
nextConcat  : (sm1, sm2 : SM) 
            -> Either sm1.State sm2.State 
            -> Char 
            -> List (Either sm1.State sm2.State, Routine)
nextConcat sm1 sm2 (Left st) c = 
  addEndRoutine 
    (acceptingConcat sm1 sm2) 
    [EmitPair] 
    (addEndTransition
      sm1.accepting 
      (mapStates Right sm2.start) 
      Left 
      (sm1.next st c))
nextConcat sm1 sm2 (Right st) c = 
  addEndRoutine 
    (acceptingConcat sm1 sm2)
    [EmitPair]
    (mapStates Right (sm2.next st c))

--- functions for Kleene Star
public export
acceptingStar : Either state () -> Bool
acceptingStar (Left _) = False
acceptingStar (Right ()) = True

public export
startStar : (sm : SM) -> List (Either sm.State (), Routine)
startStar sm = mapRoutine (EmitEList::) ((Right (), [EmitBList]) :: (mapStates Left sm.start))

public export
nextStar : (sm : SM) -> Either sm.State () -> Char -> List (Either sm.State (), Routine)
nextStar sm (Left st) c = addEndTransition sm.accepting [(Right (), [EmitBList])] Left (sm.next st c)
nextStar sm (Right ()) c = []

--- Thompson construction
public export
thompson : CoreRE -> SM
thompson (Pred f) = MkSM BaseStates acceptingPred [(StartState, [])] (nextPred f)
thompson (Empty) = MkSM Unit (\st => True) [((), [EmitUnit])] (\_,_ => [])
thompson (Group re) =
  let sm : SM := thompson re
      _ := sm.isEq
  in MkSM sm.State 
          sm.accepting 
          (groupTransform sm sm.start) 
          (\st,c => groupTransform sm (sm.next st c))

thompson (Concat re1 re2) =
  let sm1 : SM := thompson re1
      sm2 : SM := thompson re2
      _ := sm1.isEq
      _ := sm2.isEq
  in MkSM (Either sm1.State sm2.State) 
          (acceptingConcat sm1 sm2) 
          (startConcat sm1 sm2) 
          (nextConcat sm1 sm2)

thompson (Alt re1 re2) =
  let sm1 : SM := thompson re1
      sm2 : SM := thompson re2
      _ := sm1.isEq
      _ := sm2.isEq
  in MkSM (Either sm1.State sm2.State) 
          (acceptingAlt sm1 sm2) 
          (startAlt sm1 sm2) 
          (nextAlt sm1 sm2)

thompson (Star re) =
  let sm : SM := thompson re
      _ := sm.isEq
  in MkSM (Either sm.State ()) 
          acceptingStar 
          (startStar sm) 
          (nextStar sm)
