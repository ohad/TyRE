module Extra

import Data.List
import Data.List.Elem
import Data.Vect
import Data.Vect.Elem
import Data.Maybe
import Pred

public export
mapMaintainsLength: {a,b : Type} -> (xs: List a) -> (f: a -> b) -> (length xs = length (map f xs))
mapMaintainsLength [] f = Refl
mapMaintainsLength (x :: xs) f = cong (1+) (mapMaintainsLength xs f)

public export
lengthOfConcatIsPlus : (xs: List a) -> (ys: List a) -> (length xs + length ys = length (xs ++ ys))
lengthOfConcatIsPlus [] ys = Refl
lengthOfConcatIsPlus (x :: xs) ys = cong (1+) (lengthOfConcatIsPlus xs ys)

||| Proof that if an element is found on the list it belongs to that list.
public export
foundImpliesExists : (xs : List a) -> (pred : a -> Bool) -> (prf : find pred xs = Just elem) -> (elem : a ** (elem `Elem` xs, pred elem = True))
foundImpliesExists [] _ Refl impossible
foundImpliesExists (x :: xs) pred prf with (pred x) proof p
  foundImpliesExists (x :: xs) pred prf | False =
    let (elem ** (inTail, eq)) = foundImpliesExists xs pred prf
    in (elem ** (There inTail, eq))
  foundImpliesExists (x :: xs) pred prf | True = (x ** (Here, p))

||| Map Just
public export
mapJust : (f : a -> b) -> (m : Maybe a) -> (prf : map f m = Just e) -> (elem: a ** (f elem = e, m = Just elem))
mapJust _ Nothing Refl impossible
mapJust f (Just x) Refl = (x ** (Refl, Refl))

||| Extract value from Just
public export
fromJust: (m: Maybe a) -> (prf: m = Just x) -> a
fromJust (Just x) Refl = x

||| Proof that if an element belongs to concatenetion of lists xs ++ ys it belongs either to xs of ys
public export
hereOrThereConcat: (xs: List a) -> (ys: List a) -> (elem `Elem` (xs ++ ys)) -> Either (elem `Elem` xs) (elem `Elem` ys)
hereOrThereConcat [] ys x = Right x
hereOrThereConcat (elem :: xs) ys Here = Left Here
hereOrThereConcat (y :: xs) ys (There x) =
  let tail = hereOrThereConcat xs ys x
  in case tail of
    (Left e) => Left $ There e
    (Right e) => Right e

---bind proofs
foldLeftIsConcatPrfAux: (xs: List a) -> (ys: List b) -> (zs: List b) -> (f: a -> List b) -> (foldl (\acc, elem => acc ++ f elem) (ys ++ zs) xs = ys ++ foldl (\acc, elem => acc ++ f elem) (zs) xs)
foldLeftIsConcatPrfAux [] ys zs f = Refl
foldLeftIsConcatPrfAux (x :: xs) ys zs f =
  replace
    {p = \m => foldl (\acc, elem => acc ++ f elem) m xs = ys ++ foldl (\acc, elem => acc ++ f elem) (zs ++ f x) xs}
    (appendAssociative _ _ _)
    (foldLeftIsConcatPrfAux xs ys (zs ++ f x) f)

public export
foldLeftIsConcatPrf: (xs: List a) -> (x: a) -> (f: a -> List b) -> ((x::xs >>= f) = (f x) ++ (xs >>= f))
foldLeftIsConcatPrf xs x f =
  replace
    {p = \m => foldl (\acc, elem => acc ++ f elem) m xs = f x ++ foldl (\acc, elem => acc ++ f elem) [] xs}
    (appendNilRightNeutral _)
    (foldLeftIsConcatPrfAux xs (f x) [] f)

public export
bindSpec : (f : a -> List b) -> (p : Pred b) -> (q : Pred a) ->
  (spec : (x : a) -> (y: b ** (y `Elem` f x, p y)) -> q x) ->
  (cs : List a) ->
  (prf : (y: b ** (y `Elem` (cs >>= f), p y))) ->
  (x: a ** (x `Elem` cs, q x,(y: b ** (y `Elem` (f x),  p y))))

bindSpec f p q spec [] prf = absurd $ fst $ snd prf
bindSpec f p q spec (x :: xs) (y ** (isElemF, satP)) =
  let hereOrThere = hereOrThereConcat (f x) (xs >>= f) (replace {p=(y `Elem`)} (foldLeftIsConcatPrf _ _ _) isElemF)
  in case hereOrThere of
    (Left prf1) => (x ** (Here, spec x (y ** (prf1, satP)), (y ** (prf1, satP))))
    (Right prf1) =>
      let (x ** (isElem, satQ, yInf)) = bindSpec f p q spec xs (y ** (prf1, satP))
      in (x ** (There isElem, satQ, yInf))

public export
extractBasedOnFst : (xs: List a) -> (ys: Vect (length xs) b) -> (x : a) -> (xInXs: x `Elem` xs) -> b
extractBasedOnFst [] [] x xInXs = absurd xInXs
extractBasedOnFst (x :: xs) (z :: ys) x Here = z
extractBasedOnFst (x' :: xs) (z :: ys) x (There pos) = extractBasedOnFst xs ys x pos
