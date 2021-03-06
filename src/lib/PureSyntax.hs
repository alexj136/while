module PureSyntax where

import qualified Data.Map as M
import qualified Data.Set as S
import Data.List (intersperse)

-- Syntax definitions for while programs. The data types below match the
-- context-free grammar in Neil Jones' book, page 32. This module also contains
-- functions for printing syntax trees.

newtype Name = Name (FilePath, String) deriving (Eq, Ord)

nameName :: Name -> String
nameName (Name (_, s)) = s

namePath :: Name -> FilePath
namePath (Name (f, _)) = f

data Program = Program
    { progName :: Name
    , readVar  :: Name
    , block    :: Block
    , writeVar :: Name
    } deriving (Eq, Ord)

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
    show (Name (fp, x)) = x

instance Show Program where
    show (Program n r b w) = (show n) ++ "read " ++ (show r) ++ " "
                        ++ (showBlock 0 b) ++ "write " ++ (show w)

instance Show Command where
    show c = showC 0 c

showBlock :: Int -> Block -> String
showBlock i [] = "{}"
showBlock i l  = "{\n"
              ++ (concat $ intersperse ";\n" $ map (showC (i + 1)) l)
              ++ "\n"
              ++ (tabs i) ++ "}\n"

showC :: Int -> Command -> String
showC i comm = tabs i ++ case comm of
    While  x b     -> "while " ++ show x ++ showBlock i b
    Assign v x     -> (show v) ++ " := " ++ show x
    IfElse e bt bf -> "if " ++ show e ++ " " ++ showBlock i bt
                   ++ (tabs i) ++ "else " ++ showBlock i bf

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

data Atom
    = AtomAsgn
    | AtomDoAsgn
    | AtomWhile
    | AtomDoWhile
    | AtomIf
    | AtomDoIf
    | AtomVar
    | AtomQuote
    | AtomHd
    | AtomDoHd
    | AtomTl
    | AtomDoTl
    | AtomCons
    | AtomDoCons
    deriving (Eq, Ord)

instance Show Atom where
    show atom = case atom of
        AtomAsgn    -> "@:="
        AtomDoAsgn  -> "@doAsgn"
        AtomWhile   -> "@while"
        AtomDoWhile -> "@doWhile"
        AtomIf      -> "@if"
        AtomDoIf    -> "@doIf"
        AtomVar     -> "@var"
        AtomQuote   -> "@quote"
        AtomHd      -> "@hd"
        AtomDoHd    -> "@doHd"
        AtomTl      -> "@tl"
        AtomDoTl    -> "@doTl"
        AtomCons    -> "@cons"
        AtomDoCons  -> "@doCons"

--------------------------------------------------------------------------------
-- Name enumeration functions
--------------------------------------------------------------------------------

namesProg :: Program -> S.Set Name
namesProg (Program n r b w) = foldr S.insert (namesBlock b) [n, r, w]

namesBlock :: Block -> S.Set Name
namesBlock = S.unions . map namesComm

namesComm :: Command -> S.Set Name
namesComm comm = case comm of
    Assign n e     -> S.insert n (namesExpr e)
    While  e b     -> S.union (namesExpr e) (namesBlock b)
    IfElse e bt bf -> S.unions [namesExpr e, namesBlock bt, namesBlock bf]

namesExpr :: Expression -> S.Set Name
namesExpr expr = case expr of
    Var  n     -> S.singleton n
    Lit  _     -> S.empty
    Cons e1 e2 -> S.union (namesExpr e1) (namesExpr e2)
    Hd   e     -> namesExpr e
    Tl   e     -> namesExpr e
    IsEq e1 e2 -> S.union (namesExpr e1) (namesExpr e2)

--------------------------------------------------------------------------------
-- Syntax Conversion & Showing Functions
--------------------------------------------------------------------------------

atomToInt :: Atom -> Int
atomToInt atom = case atom of
    AtomAsgn    ->  2
    AtomDoAsgn  ->  3
    AtomWhile   ->  5
    AtomDoWhile ->  7
    AtomIf      -> 11
    AtomDoIf    -> 13
    AtomVar     -> 17
    AtomQuote   -> 19
    AtomHd      -> 23
    AtomDoHd    -> 29
    AtomTl      -> 31
    AtomDoTl    -> 37
    AtomCons    -> 41
    AtomDoCons  -> 43

atomToTree :: Atom -> ETree
atomToTree = intToTree . atomToInt

treeToAtom :: ETree -> Maybe Atom
treeToAtom t = parseInt t >>= intToAtom

intToAtom :: Int -> Maybe Atom
intToAtom int = case int of
    2  -> Just AtomAsgn
    3  -> Just AtomDoAsgn
    5  -> Just AtomWhile
    7  -> Just AtomDoWhile
    11 -> Just AtomIf
    13 -> Just AtomDoIf
    17 -> Just AtomVar
    19 -> Just AtomQuote
    23 -> Just AtomHd
    29 -> Just AtomDoHd
    31 -> Just AtomTl
    37 -> Just AtomDoTl
    41 -> Just AtomCons
    43 -> Just AtomDoCons
    _  -> Nothing

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
showNestedAtomIntListTree = tryAtomThenIntThenList
    where
    tryIntThenList :: ETree -> String
    tryIntThenList t = case parseInt t of
        Just i  -> show i
        Nothing -> case toHaskellList t of
            []   -> "0" -- unreachable as this would parse as an int
            e:es -> showStringsAsList $
                tryAtomThenIntThenList e : (map tryIntThenList es)
    tryAtomThenIntThenList :: ETree -> String
    tryAtomThenIntThenList t = case treeToAtom t of
        Just a  -> show a
        Nothing -> tryIntThenList t

showProgramTree :: ETree -> Maybe String
showProgramTree e = case toHaskellList e of
    [x, blk, y] -> do
        xi     <- parseInt x
        yi     <- parseInt y
        blkStr <- showBlockTree 1 blk
        return $ showStringsAsListFmt 0 [show xi, blkStr, show yi]
    _ -> Nothing

showBlockTree :: Int -> ETree -> Maybe String
showBlockTree t blk = do
    comms <- sequence $ map (showCommandTree (succ t)) $ toHaskellList blk
    return $ showStringsAsListFmt t comms

showCommandTree :: Int -> ETree -> Maybe String
showCommandTree t e = case toHaskellList e of
    [atomT, arg1, arg2] -> do
        atom  <- treeToAtom atomT
        case atom of
            AtomWhile -> do
                exp <- showExpressionTree arg1
                blk <- showBlockTree (succ t) arg2
                return $ showStringsAsListFmt t
                    [((show atom) ++ ", " ++ exp), blk]
            AtomAsgn  -> do
                var <- parseInt           arg1
                exp <- showExpressionTree arg2
                return $ showStringsAsList [show atom, show var, exp]
            _ -> Nothing
    [atomT, arg1, arg2, arg3] -> do
        atom  <- treeToAtom atomT
        case atom of
            AtomIf -> do
                exp <- showExpressionTree arg1
                bt  <- showBlockTree (succ t) arg2
                bf  <- showBlockTree (succ t) arg3
                return $ showStringsAsListFmt t
                    [((show atom) ++ ", " ++ exp), bt, bf]
            _ -> Nothing
    _ -> Nothing

showExpressionTree :: ETree -> Maybe String
showExpressionTree e = case toHaskellList e of
    [atomT, arg1, arg2] -> do
        atom  <- treeToAtom atomT
        case atom of
            AtomCons -> do
                hdE <- showExpressionTree arg1
                tlE <- showExpressionTree arg2
                return $ showStringsAsList [show atom, hdE, tlE]
            _        -> Nothing
    [atomT, ENil] -> do
        atom  <- treeToAtom atomT
        case atom of
            AtomQuote -> return $ showStringsAsList [show atom, show ENil]
            AtomVar   -> return $ showStringsAsList [show atom, show 0   ]
            _         -> Nothing
    [atomT, arg] -> do
        atom  <- treeToAtom atomT
        case atom of
            AtomVar   -> do
                var <- parseInt arg
                return $ showStringsAsList [show atom, show var]
            AtomHd    -> do
                exp <- showExpressionTree arg
                return $ showStringsAsList [show atom, exp]
            AtomTl    -> do
                exp <- showExpressionTree arg
                return $ showStringsAsList [show atom, exp]
            _ -> Nothing
    _ -> Nothing

-- Parse an Int from a while Expression. Not all while expressions encode
-- integers, so return a value in the Maybe monad.
parseInt :: ETree -> Maybe Int
parseInt = parseIntAcc 0
    where
    parseIntAcc :: Int -> ETree -> Maybe Int
    parseIntAcc acc ENil           = Just acc
    parseIntAcc acc (ECons ENil x) = parseIntAcc (acc + 1) x
    parseIntAcc acc _              = Nothing

-- Makes an Expression from an Int, using accumulating parameter style
intToTree :: Int -> ETree
intToTree = intToTreeAcc ENil
    where
    intToTreeAcc acc 0 = acc
    intToTreeAcc acc n = intToTreeAcc (ECons ENil acc) (n - 1)

-- Convert a while expression encoded list into a haskell list
toHaskellList :: ETree -> [ETree]
toHaskellList = reverse . (toHaskellListAcc [])
    where
    toHaskellListAcc :: [ETree] -> ETree -> [ETree]
    toHaskellListAcc acc exp = case exp of
        ENil              -> acc
        (ECons elem rest) -> toHaskellListAcc (elem : acc) rest

-- Given a function to show an ETree and a list of ETrees, show a a list of
-- ETrees where the elements are shown by the given function
showListOf :: (ETree -> String) -> [ETree] -> String
showListOf showFn = showStringsAsList . map showFn

-- Take a list of strings, intersperse ", " within them, concatenate them and
-- add square brackets around that
showStringsAsList :: [String] -> String
showStringsAsList ss = "[" ++ (concat $ intersperse ", " ss) ++ "]"

-- showStringsAsList with one element per line and indentation
showStringsAsListFmt :: Int -> [String] -> String
showStringsAsListFmt t []     = "[]"
showStringsAsListFmt t (s:[]) = "\n"
    ++ (tabs t) ++ "[ " ++ s ++ "\n"
    ++ (tabs t) ++ "]"
showStringsAsListFmt t (s:ss) = "\n"
    ++ (tabs t) ++ "[ " ++ s ++ "\n"
    ++ (tabs t) ++ ", "
        ++ (concat $ intersperse ("\n" ++ (tabs t) ++ ", ") ss) ++ "\n"
    ++ (tabs t) ++ "]"

-- Convert a list of Expressions into a single list expression
expFromHaskellList :: [Expression] -> Expression
expFromHaskellList (h:t) = Cons h (expFromHaskellList t)
expFromHaskellList []    = Lit ENil

-- Convert a list of ETrees into a single list ETree
treeFromHaskellList :: [ETree] -> ETree
treeFromHaskellList (h:t) = ECons h (treeFromHaskellList t)
treeFromHaskellList []    = ENil
