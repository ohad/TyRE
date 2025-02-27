module API

import public Core
import Evidence
import NFA
import Verification.AcceptingPath
import Verification
import Verification.Thompson
import TyRE
import Data.Stream
import Thompson
import DisjointMatches

runAutomatonSM : SM -> Word -> Maybe Evidence
runAutomatonSM sm word = runAutomaton word

runAutomatonSMStream : SM -> Stream Char -> (Maybe Evidence, Stream Char)
runAutomatonSMStream sm stream = runAutomatonStream stream

match : {re : CoreRE} -> (sm : SM) -> {auto prf : thompson re = sm}
      -> Word -> Maybe (Shape re)
match {re} sm {prf} str with (runAutomatonSM sm str) proof p
  match {re} sm {prf} str | Nothing = Nothing
  match {re} sm {prf} str | Just ev =
    let 0 acc = extractEvidenceEquality (thompson re) str ev (rewrite prf in p)
        0 encodes = thompsonPrf re (fst acc)
    in Just $ extract ev (rewrite (sym $ snd acc) in encodes)

runWord : (re : CoreRE) -> List Char -> Maybe (Shape re)
runWord re str = match (thompson re) str

export
run : (re : CoreRE) -> String -> Maybe (Shape re)
run re str = runWord re (unpack str)

matchStream : {re : CoreRE} -> (sm : SM) -> {auto prf : thompson re = sm}
            -> Stream Char -> Maybe (Shape re, Stream Char)
matchStream {re} sm {prf} stm with (runAutomatonSMStream sm stm) proof p
  matchStream {re} sm {prf} stm | (Nothing, stmTail) = Nothing
  matchStream {re} sm {prf} stm | (Just ev, stmTail) =
    let 0 stmEq := eqForStream (thompson re) stm
        0 acc := extractEvidenceEquality (thompson re) (fst stmEq) ev (trans (snd stmEq) (rewrite prf in (cong fst p)))
        0 encodes := thompsonPrf re (fst acc)
    in Just (extract ev (rewrite (sym $ snd acc) in encodes), stmTail)

export
getTokenCore : (re : CoreRE) -> Stream Char -> Maybe (Shape re, Stream Char)
getTokenCore re stm = matchStream (thompson re) stm

matchPrefix : {re : CoreRE} -> (sm : SM) -> {auto prf : thompson re = sm}
            -> Word -> Maybe (Shape re, Word)
matchPrefix {re} sm {prf} stm with (runAutomatonPrefix stm) proof p
  matchPrefix {re} sm {prf} stm | Nothing = Nothing
  matchPrefix {re} sm {prf} stm | Just (ev, stmTail) =
    let 0 stmEq := eqForPrefix (thompson re) stm
        0 acc := 
          extractEvidenceEquality (thompson re)
                                  (fst stmEq)
                                  ev
                                  (trans  (snd stmEq)
                                          (rewrite prf in (cong (map fst) p)))
        0 encodes := thompsonPrf re (fst acc)
    in Just (extract ev (rewrite (sym $ snd acc) in encodes), stmTail)

asDisjoinMatchesFrom : {re : CoreRE} -> (sm : SM) -> {auto prf : thompson re = sm}
                    -> Word -> DisjointMatchesSnoc (Shape re) -> DisjointMatchesSnoc (Shape re)
asDisjoinMatchesFrom sm [] dm = dm
asDisjoinMatchesFrom sm {prf} (c :: cs) dm = 
  case (matchPrefix sm {prf} (c :: cs)) of
    Nothing => asDisjoinMatchesFrom sm cs (dm :< c)
    (Just (parse, tail)) => asDisjoinMatchesFrom sm tail (dm :+: parse)

export
asDisjoinMatchesCore : (re : CoreRE) -> String -> DisjointMatches (Shape re)
asDisjoinMatchesCore re str = cast $ asDisjoinMatchesFrom {re} (thompson re) (unpack str) (Prefix [<])