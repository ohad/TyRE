import API
import Core
import Thompson
import Evidence
import Data.Maybe

A : CoreRE
A = CharPred (Pred (\c =>  c == 'a'))

createRE : Nat -> CoreRE
createRE 0 = A
createRE (S k) = A `Concat` (createRE k)

createString : Nat -> List Char
createString 0 = ['a']
createString (S k) = 'a'::(createString k)

printResult : (n: Nat) -> Maybe (Shape $ createRE n)
printResult n = run (createRE n) (pack $ createString n)

main : IO ()
main =  do  str <- getLine
            if all isDigit (unpack str)
              then
                let n : Nat
                    n = (cast str)
                in case printResult n of
                    Just res => putStrLn (showAux res)
                    Nothing => putStrLn "Error\n"
              else putStrLn "Input is not a number\n"
