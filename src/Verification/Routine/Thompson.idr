module Verification.Routine.Thompson

import NFA
import NFA.Thompson
import Evidence
import Verification.AcceptingPath
import Extra
import Data.List
import Core
import Codes
import Data.SnocList
import Data.SnocList.Extra
import Verification.Routine
import Data.List.Elem
import Verification.Routine.Thompson.Group
import Data.Vect
import Extra.Reflects
import Verification.Routine.Thompson.Concat

pairEq: (x : (a,b)) -> ((fst x, snd x) = x)
pairEq (x, y) = Refl

thompsonRoutinePrf : (re : CoreRE)
                  -> (acc : Accepting (thompson re).nfa word)
                  -> (mcvm  : (Maybe Char, VMState))
                  -> (ev  : Evidence ** (executeRoutineFrom (extractRoutine (thompson re).nfa (thompson re).prog acc) mcvm = (snd mcvm).evidence ++ ev, ev `Encodes` [< ShapeCode re]))

thompsonRoutinePrf (Pred f) (Start s (There prf) x) mcvm = absurd prf
thompsonRoutinePrf {word = []} (Pred f) (Start StartState Here (Accept StartState prf)) mcvm = absurd prf
thompsonRoutinePrf {word = c::_} (Pred f) (Start StartState Here (Step StartState c t prf acc)) mcvm with (f c)
  thompsonRoutinePrf {word = c::_} (Pred f) (Start StartState Here (Step StartState c t prf acc)) mcvm | False = absurd prf
  thompsonRoutinePrf {word = c::_} (Pred f) (Start StartState Here (Step StartState c t (There prf) acc)) mcvm | True = absurd prf
  thompsonRoutinePrf {word = c::c'::_} (Pred f) (Start StartState Here (Step StartState c AcceptState Here (Step AcceptState c' t prf acc))) mcvm | True = absurd prf
  thompsonRoutinePrf {word = [c]} (Pred f) (Start StartState Here (Step StartState c AcceptState Here (Accept AcceptState Refl))) (mc, vm) | True = ([< CharMark c] ** (Refl, AChar [<] c))

thompsonRoutinePrf (Concat re1 re2) acc mcvm =
  let (word1 ** (acc1 ** (word2 ** (acc2 ** eqPrf)))) = concatEvidencePrf re1 re2 acc
      exr1 : ExtendedRoutine
      exr1 = extractRoutine (thompson re1).nfa (thompson re1).prog acc1
      exr2 : ExtendedRoutine
      exr2 = extractRoutine (thompson re2).nfa (thompson re2).prog acc2
      (ev1 ** (eq1, encodes1)) := thompsonRoutinePrf re1 acc1 mcvm
      vmmc' : (Maybe Char, VMState)
      vmmc' = executeRoutineSteps exr1 mcvm
      (ev2 ** (eq2, encodes2)) := thompsonRoutinePrf re2 acc2 vmmc'
      prf : ((snd $ executeRoutineSteps (exr1 ++ exr2 ++ [Regular EmitPair]) mcvm).evidence = (snd $ executeRoutineSteps exr2 (executeRoutineSteps exr1 mcvm)).evidence :< PairMark)
      prf = ?hole
  in rewrite eqPrf in rewrite prf in (ev1 ++ ev2 ++ [< PairMark] ** rewrite eq2 in (rewrite eq1 in (cong (:< PairMark) (sym $ appendAssociative), ?kkk)))

thompsonRoutinePrf (Group re) (Start (Right z) initprf acc) _ = absurd (rightCantBeElemOfLeft _ _ initprf)
thompsonRoutinePrf (Group re) (Start (Left z) initprf (Accept (Left z) pos)) _ = absurd pos
thompsonRoutinePrf (Group re) (Start (Left z) initprf (Step (Left z) c t prf acc)) (mc,vm) =
  let q := extractBasedOnFstFromRep (thompson (Group re)).nfa.start ((the Routine) [Record]) (Left z) initprf
      (w ** ev) := evidenceForGroup re {mc,ev = vm.evidence} (Step {nfa = (thompson (Group re)).nfa} (Left z) c t prf acc) (MkVMState True vm.memory vm.evidence) Refl
  in ([< GroupMark w] ** rewrite q in (rewrite ev in (Refl, AGroup [<] w)))

thompsonPrf : (re : CoreRE)
            -> (acc: Accepting (thompson re).nfa word)
            -> (extractEvidence {nfa = (thompson re).nfa, prog = (thompson re).prog} acc `Encodes` [< ShapeCode re])

thompsonPrf re acc =
  let rprf := extractRoutinePrf (thompson re).nfa (thompson re).prog acc
      (ev ** (concat, encodes)) := thompsonRoutinePrf re acc (Nothing, initVM)
      prf : (ev = extractEvidence {nfa = (thompson re).nfa, prog = (thompson re).prog} acc)
      prf = trans (sym $ appendNilLeftNeutral {x = ev}) (trans (sym concat) rprf)
  in replace {p=(\e => e `Encodes` [< ShapeCode re])} prf encodes
