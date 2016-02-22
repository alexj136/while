module PureSyntax where

import qualified Data.Map as M
import Data.List (intersperse)

-- Syntax definitions for while programs. The data types below match the
-- context-free grammar in Neil Jones' book, page 32. This module also contains
-- functions for printing syntax trees.

newtype Name = Name (FilePath, String) deriving (Eq, Ord)

nameName :: Name -> String
nameName (Name (_, s)) = s

namePath :: Name -> FilePath
namePath (Name (f, _)) = f

data Program
    = Program Name Block Name
    deriving (Eq, Ord)

type Block = [Command]

data Command
    = Assign Name       Expression
    | While  Expression Block
    | IfElse Expression Block Block
    deriving (Eq, Ord)

data Expression
    = Var  Name  
    | Lit  ETree
    | Cons Expression Expression
    | Hd   Expression
    | Tl   Expression
    | IsEq Expression Expression
    deriving (Eq, Ord)

-- ETrees are evaluated expressions - just cons and nil.
data ETree = ECons ETree ETree | ENil deriving (Eq, Ord)

instance Show Name where
    show (Name (fp, x)) = "<<" ++ x ++ " of " ++ fp ++ ">>"

instance Show Program where
    show (Program n c w) = "read " ++ (show n) ++ " {\n"
                        ++ (show c) ++ "\n"
                        ++ "} write " ++ (show w)

instance Show Command where
    show c = showC 0 c

showBlock :: Int -> Block -> String
showBlock i [] = "{}"
showBlock i l  = (tabs i) ++ "{\n"
              ++ (concat $ intersperse ";\n" $ map (showC (i + 1)) l)
              ++ "\n"
              ++ (tabs i) ++ "}\n"

showC :: Int -> Command -> String
showC i comm = tabs i ++ case comm of
    While  x b     -> "while " ++ show x ++ showBlock (i + 1) b
    Assign v x     -> (show v) ++ " := " ++ show x
    IfElse e bt bf -> "if " ++ show e ++ " " ++ showBlock (i + 1) bt
                   ++ (tabs i) ++ "else " ++ showBlock (i + 1) bf

tabs :: Int -> String
tabs x | x <  0 = error "negative tabs"
       | x == 0 = ""
       | x >  0 = "    " ++ tabs (x - 1)

instance Show Expression where
    show (Var  s  ) = show s
    show (Lit  t  ) = show t
    show (Cons a b) = "(cons " ++ show a ++ " " ++ show b ++ ")"
    show (Hd   x  ) = "hd " ++ show x
    show (Tl   x  ) = "tl " ++ show x
    show (IsEq a b) = show a ++ " = " ++ show b

instance Show ETree where
    show  ENil       = "nil"
    show (ECons l r) = "<" ++ show l ++ "." ++ show r ++ ">"

-- Convert a while integer expression into a decimal number string. If the
-- isVerbose argument is True, unparsable expressions will be displayed in full.
-- If it is False, unparsable expressions yield "E".
showIntTree :: Bool -> ETree -> String
showIntTree isVerbose e =
    maybe (if isVerbose then show e else "E") show (parseInt e)

showIntListTree :: Bool -> ETree -> String
showIntListTree isVerbose e =
    showListOf (showIntTree isVerbose) (toHaskellList e)

showNestedIntListTree :: ETree -> String
showNestedIntListTree e = maybe
    (showListOf showNestedIntListTree (toHaskellList e)) show (parseInt e)

showNestedAtomIntListTree :: ETree -> String
showNestedAtomIntListTree e = case parseInt e of
    Just  2 -> "@asgn"
    Just  3 -> "@doAsgn"
    Just  5 -> "@while"
    Just  7 -> "@doWhile"
    Just 11 -> "@if"
    Just 13 -> "@doIf"
    Just 17 -> "@var"
    Just 19 -> "@quote"
    Just 23 -> "@hd"
    Just 29 -> "@doHd"
    Just 31 -> "@tl"
    Just 37 -> "@doTl"
    Just 41 -> "@cons"
    Just 43 -> "@doCons"
    Just  i -> show i
    Nothing -> showListOf showNestedAtomIntListTree (toHaskellList e)

-- Parse an Int from a while Expression. Not all while expressions encode
-- integers, so return a value in the Maybe monad.
parseInt :: ETree -> Maybe Int
parseInt = parseIntAcc 0
    where
    parseIntAcc :: Int -> ETree -> Maybe Int
    parseIntAcc acc ENil           = Just acc
    parseIntAcc acc (ECons ENil x) = parseIntAcc (acc + 1) x
    parseIntAcc acc _              = Nothing

-- Convert a while expression encoded list into a haskell list
toHaskellList :: ETree -> [ETree]
toHaskellList = reverse . (toHaskellListAcc [])
    where
    toHaskellListAcc :: [ETree] -> ETree -> [ETree]
    toHaskellListAcc acc exp = case exp of
        ENil              -> acc
        (ECons elem rest) -> toHaskellListAcc (elem : acc) rest

-- given a function to show an ETree and a list 
showListOf :: (ETree -> String) -> [ETree] -> String
showListOf showFn l = "[" ++ (concat $ intersperse ", " $ (map showFn l)) ++ "]"
