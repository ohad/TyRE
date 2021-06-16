module Verification

import NFA
import Evidence
import Data.List.Elem
import Data.List
import Data.Vect
import Data.Vect.Elem
import Extra
import Pred

data AcceptingFrom : (nfa : NA) -> (s : nfa.State) -> (word : Word) -> Type where
  Accept : {auto nfa : NA} -> (s : nfa.State) -> (prf : nfa.accepting s = True) -> AcceptingFrom nfa s []
  Step   : {auto nfa : NA} -> (s : nfa.State) -> (c : Char) -> (t : nfa.State)
        -> (prf : t `Elem` (nfa.next s c))
        -> AcceptingFrom nfa t w
        -> AcceptingFrom nfa s (c :: w)

data Accepting : (nfa : NA) -> (word : Word) -> Type where
  Start : {auto nfa : NA} -> (s : nfa.State) -> (prf : s `Elem` nfa.start) -> AcceptingFrom nfa s w
       -> Accepting nfa w


runMappingSpec : {auto nfa : NA} -> {auto prog: Program nfa} -> (c: Char) -> (td : Thread nfa)
              -> (td': Thread nfa ** (td' `Elem` (runMapping c . step c) td, AcceptingFrom nfa (fst td') cs))
              -> AcceptingFrom nfa td.naState (c::cs)

runMappingSpec c td (td' ** (isElemOfF, accepts)) =
  let acc : AcceptingFrom nfa ((step c td) .naState) (c :: cs)
      acc = Step (fst (step c td)) c (td'.naState) (runFromStepState c (step c td) td' isElemOfF) accepts
  in replace {p=(\st => AcceptingFrom nfa st (c :: cs))} (fst $ (stepMaintainsState c td)) acc

recordPath : {auto nfa : NA} -> {auto prog : Program nfa} -> (tds : List (Thread nfa)) -> (str : Word)
          -> (prf : runFrom str tds = Just ev)
          -> (td : Thread nfa ** (td `Elem` tds, AcceptingFrom nfa (fst td) str))

recordPath tds [] prf =
  let (x ** (_, woMap)) = mapJust _ _ prf
      (td ** (tdInTds, accept)) = foundImpliesExists _ _ woMap
  in (td ** (tdInTds, Accept (fst td) accept))

recordPath {nfa} tds (c :: cs) prf =
  let (x ** (isElem, satQ , _)) =
        bindSpec
          (runMapping c . step c)
          (\e => AcceptingFrom nfa (fst e) cs)
          (\e => AcceptingFrom nfa (fst e) (c :: cs))
          (runMappingSpec c)
          tds
          (recordPath _ cs prf)
  in (x ** (isElem, satQ))

extractEvidenceFrom : {auto nfa : NA} -> {auto prog : Program nfa} -> (td : Thread nfa) -> AcceptingFrom nfa (fst td) word -> Evidence
extractEvidenceFrom td (Accept (fst td) prf) = (snd td).evidence
extractEvidenceFrom td (Step {w} (fst td) c t prf acc) =
  let r : Routine
      r = extractBasedOnFst (nfa .next td.naState c) (prog .next td.naState c) t prf
      v : VMState
      v = (runFunction c (step c td) (t,r)).vmState
  in extractEvidenceFrom (t, v) acc

extractEvidence : {auto nfa : NA} -> {auto prog : Program nfa} -> Accepting nfa word -> Evidence
extractEvidence (Start {w} s prf acc) =
  let r : Routine
      r = extractBasedOnFst (nfa .start) (prog .init) s prf
      v : VMState
      v = (initFuction (s,r)).vmState
  in extractEvidenceFrom (s, v) acc
