import API
import RE
import Data.Either

rightRE : Nat -> TyRE Nat
rightRE 0 = (\_ => 1) `Conv` match 'a'
rightRE (S k) = (\case {Left () => 1; Right n => n+1}) `Conv` (match 'a' <|> rightRE k)

leftRE : Nat -> TyRE Nat
leftRE 0 = (\_ => 1) `Conv` match 'a'
leftRE (S k) = (\case {Left n => n; Right () => (S k)}) `Conv` (rightRE k <|> match 'a')

main : IO ()
main =  do  str <- getLine
            if all isDigit (unpack str)
              then
                let n : Nat
                    n = (cast str)
                in case parse (rightRE n) "a" of
                    Just res => putStrLn $ show $ res
                    Nothing => putStrLn "Error"
              else putStrLn "Input should be two numbers"
