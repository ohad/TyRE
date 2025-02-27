import API
import Core
import Codes
import Thompson

AorB : CoreRE
AorB = CharPred (Pred (\c =>  (c == 'a' || c == 'b')))

AOrBStar: CoreRE
AOrBStar = Star AorB

printResult : String -> IO ()
printResult str = putStrLn $ show $ run AOrBStar str

main : IO ()
main = do printResult "bab"
          printResult "bba"
          printResult "aaa"
          printResult "aac"
          printResult "aaaa"
