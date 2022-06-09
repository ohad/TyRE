module Verification.Thompson

import Core
import Thompson
import NFA
import Evidence
import Extra

import Verification.AcceptingPath
import Verification.Routine
import Verification.Thompson.Predicate
import Verification.Thompson.Group

import Data.SnocList
import Data.List.Elem

thompsonRoutinePrf : (re : CoreRE)
                  -> {word : Word}
                  -> (acc : Accepting (smToNFA (thompson re)) word)
                  -> (mcvm  : (Maybe Char, VMState))
                  -> (ev  : Evidence
                        ** (executeRoutineFrom (extractRoutine {sm = (thompson re)} acc) mcvm
                              = (snd mcvm).evidence ++ ev, ev `Encodes` [< Right $ ShapeCode re]))

thompsonRoutinePrf Empty {word = []} (Start Nothing Here Accept) (mc, vm) = ([< UnitMark] ** (Refl, AnEmpty [<]))
thompsonRoutinePrf Empty (Start (Just ()) Here acc) (mc, vm) impossible
thompsonRoutinePrf Empty (Start (Just ()) (There _) acc) (mc, vm) impossible
thompsonRoutinePrf (Pred f) acc mcvm = thompsonRoutinePrfPredicate f acc mcvm
thompsonRoutinePrf {word} (Group re) acc mcvm = 
  let routineEq = thompsonRoutinePrfGroup re acc
      (snocWord ** evidanceEq) = runGroupRoutine word mcvm
  in rewrite routineEq in ([< GroupMark snocWord] ** (evidanceEq, AGroup [<] snocWord))
thompsonRoutinePrf (Concat x y) acc mcvm = ?thompsonRoutinePrf_rhs_1
thompsonRoutinePrf (Alt x y) acc mcvm = ?thompsonRoutinePrf_rhs_4
thompsonRoutinePrf (Star x) acc mcvm = ?thompsonRoutinePrf_rhs_5

export
thompsonPrf : (re : CoreRE)
            -> {word : Word}
            -> (acc: Accepting (smToNFA (thompson re)) word)
            -> (extractEvidence {sm = thompson re} acc `Encodes` [< Right $ ShapeCode re])

thompsonPrf re acc =
  let sm : SM
      sm = thompson re
      rprf := extractRoutinePrf {sm} acc
      (ev ** (concat, encodes)) := thompsonRoutinePrf re acc (Nothing, initVM)
      prf : (ev = extractEvidence {sm} acc)
      prf = trans (sym (appendLinLeftNeutral ev)) (trans (sym concat) rprf)
  in replace {p=(\e => e `Encodes` [< Right $ ShapeCode re])} prf encodes

