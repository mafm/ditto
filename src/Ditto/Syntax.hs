module Ditto.Syntax where
import Data.List
import Data.Maybe
import Data.ByteString.Char8 (ByteString, pack, unpack)
import qualified Data.Map as Map

----------------------------------------------------------------------

snoc :: [a] -> a -> [a]
snoc xs x = xs ++ [x]

reject :: (a -> Bool) -> [a] -> [a]
reject p = filter (not . p)

----------------------------------------------------------------------

data Verbosity = Normal | Verbose
  deriving (Show, Read, Eq)

data Icit = Expl | Impl
  deriving (Show, Read, Eq)

data Essible = Acc | Inacc
  deriving (Show, Read, Eq, Ord)

----------------------------------------------------------------------

data Name = Name Essible ByteString (Maybe Integer)
  deriving (Read, Eq, Ord)

instance Show Name where
  show (Name e x m) = prefix ++ unpack x ++ suffix
    where
    prefix = case e of Acc -> ""; Inacc -> "."
    suffix = case m of Nothing -> ""; Just n -> "$" ++ show n

bs2n :: Essible -> ByteString -> Name
bs2n e x = Name e x Nothing

s2n :: Essible -> String -> Name
s2n e x = bs2n e (pack x)

uniqName :: Name -> Integer -> Name
uniqName x@(Name e _ _) n = uniqEName e x n

uniqEName :: Essible -> Name -> Integer -> Name
uniqEName e (Name _ x _) n = Name e x (Just n)

isInacc :: Name -> Bool
isInacc (Name Inacc _ _) = True
isInacc _ = False

----------------------------------------------------------------------

newtype PName = PName ByteString
  deriving (Read, Eq, Ord)

instance Show PName where
  show (PName x) = "#" ++ unpack x

pname2name :: PName -> Name
pname2name (PName x) = Name Acc x Nothing

name2pname :: Name -> Maybe PName
name2pname (Name Acc x Nothing) = Just (PName x)
name2pname _ = Nothing

----------------------------------------------------------------------

newtype GName = GName Integer
  deriving (Read, Eq, Ord)

instance Show GName where
  show (GName n) = "!" ++ show n

----------------------------------------------------------------------

data MName = MName MKind Integer
  deriving (Read, Eq, Ord)

instance Show MName where
  show (MName k n) = "?" ++ prefix k ++ show n
    where
    prefix :: MKind -> String
    prefix MInfer = ""
    prefix (MHole Nothing) = ""
    prefix (MHole (Just nm)) = unpack nm ++ "-"

data MKind = MInfer | MHole (Maybe ByteString)
  deriving (Show, Read, Eq, Ord)

----------------------------------------------------------------------

type Prog = [MStmt]
type MStmt = Either Stmt [Stmt]
data Stmt =
    SDef PName Exp Exp
  | SData PName Exp SCons
  | SDefn PName Exp SClauses
  deriving (Show, Read, Eq)
type SCons = [(PName, Exp)]
type SClauses = [SClause]
type SClause = (Pats, RHS)

data Sig =
    GDef PName Exp
  | GData PName Exp
  | GDefn PName Exp Icits
  deriving (Show, Read, Eq)

data Bod =
    BDef PName Exp
  | BData PName SCons
  | BDefn PName SClauses
  deriving (Show, Read, Eq)

data Exp =
    EType | EPi Icit Exp Bind | ELam Icit Exp Bind
  | EForm PName Args | ECon PName PName Args
  | ERed PName Args | EMeta MName Args
  | EVar Name | EGuard GName
  | EApp Icit Exp Exp | EInfer MKind
  deriving (Show, Read, Eq)

data Bind = Bind Name Exp
  deriving (Show, Read, Eq)

type Icits = [Icit]
type Args = [Arg]
type Arg = (Icit, Exp)
type Env = [Crumb]
type Tel = [(Icit, Name, Exp)]
type Ren = [(Name, Name)]
type Sub = [(Name, Exp)]
type PSub = [(Name, Pat)]
type Acts = [(Tel, Act)]
type CtxErr = ([Name], Prog, Acts, Tel, Err)
type Flex = Either MName GName

type Holes = [Hole]
type Hole = (MName, Meta)

type Forms = Map.Map PName Tel

type Conss = Map.Map PName Cons
type Cons = [(PName, Con)]
data Con = Con Tel Args
  deriving (Show, Read, Eq)

type Reds = Map.Map PName Red
data Red = Red Tel Exp
  deriving (Show, Read, Eq)

type Clausess = Map.Map PName Clauses
type Clauses = [Clause]
data Clause = Clause Tel Pats RHS
  deriving (Show, Read, Eq)

type Metas = Map.Map MName Meta
data Meta = Meta Acts Tel Exp
  deriving (Show, Read, Eq)
type Sols = Map.Map MName Exp

type Defs = Map.Map Name Ann
type Guards = Map.Map GName Ann
data Ann = Ann { val, typ :: Exp }
  deriving (Show, Read)

type MProb = Maybe Prob
type Probs = Map.Map GName Prob
data Prob =
    Prob1 Acts Tel Exp Exp
  | ProbN Prob Acts Tel Args Args
  deriving (Show, Read, Eq)

type Pats = [(Icit, Pat)]
data RHS = MapsTo Exp | Caseless Name | Split Name
  deriving (Show, Read, Eq)

data Crumb = CData PName | CDefn PName
  deriving (Show, Read, Eq)

data Pat = PVar Name | PInacc (Maybe Exp) | PCon PName Pats
  deriving (Show, Read, Eq)

data Act =
    ACheck Exp Exp
  | AConv Exp Exp
  | ACover PName Pats
  | ADef PName
  | AData PName
  | AClause Clause
  | ACon PName
  | ADefn PName
  deriving (Show, Read, Eq)

data Err =
    RGen String
  | RConv Exp Exp
  | RScope Name
  | RCaseless Name
  | RUnsolved [Prob] Holes
  | RReach PName SClauses
  | RSplit Clauses
  | RAtom Exp
  deriving (Show, Read, Eq)

----------------------------------------------------------------------

toSig :: Stmt -> Sig
toSig (SDef x _ _A) = GDef x _A
toSig (SData x _A _) = GData x _A
toSig (SDefn x _A cs) = GDefn x _A (coverIcits cs)

toBod :: Stmt -> Bod
toBod (SDef x a _) = BDef x a
toBod (SData x _ cs) = BData x cs
toBod (SDefn x _ cs) = BDefn x cs

----------------------------------------------------------------------

names :: Tel -> [Name]
names = map $ \(_,x,_) -> x

coverIcits :: SClauses -> Icits
coverIcits [] = []
coverIcits ((ps,_):_) = map fst ps

lookupTel :: Name -> Tel -> Maybe Exp
lookupTel x = lookup x . map (\(_,x,a) -> (x, a))

varArgs :: Tel -> Args
varArgs = map $ \(i,x,_) -> (i, EVar x)

pvarPats :: Tel -> Pats
pvarPats = map (\(i, x, _) -> (i, PVar x))

pis :: Tel -> Exp -> Exp
pis = flip $ foldr $ \ (i, x, _A) _B -> EPi i _A (Bind x _B)

ipis :: Tel -> Exp -> Exp
ipis as = pis (map (\(_,x,a) -> (Impl,x,a)) as)

paramCons :: Tel -> SCons -> SCons
paramCons _As = map (\(x, _A) -> (x, ipis _As _A))

lams :: Tel -> Exp -> Exp
lams = flip $ foldr $ \ (i, x , _A) _B -> ELam i _A (Bind x _B)

apps :: Exp -> Args -> Exp
apps = foldl $ \ f (i, a) -> EApp i f a

hole :: Exp
hole = EInfer (MHole Nothing)

----------------------------------------------------------------------

formType :: Tel -> Exp
formType _Is = pis _Is EType

conType :: Tel -> PName -> Args -> Exp
conType _As _X _Is = pis _As (EForm _X _Is)

----------------------------------------------------------------------

viewSpine :: Exp -> (Exp, Args)
viewSpine (EApp i f a) = (g, snoc as (i, a))
  where (g, as) = viewSpine f
viewSpine x = (x, [])

----------------------------------------------------------------------

fv :: Exp -> [Name]
fv (EVar x) = [x]
fv EType = []
fv (EInfer _) = []
fv (EGuard _) = []
fv (EForm _ is) = fvs is
fv (ECon _ _ as) = fvs as
fv (ERed _ as) = fvs as
fv (EMeta _ as) = fvs as
fv (EPi _ _A _B) = fv _A ++ fvBind _B
fv (ELam _ _A b) = fv _A ++ fvBind b
fv (EApp _ a b) = fv a ++ fv b

fvs :: Args -> [Name]
fvs as = concatMap fv (map snd as)

fvBind :: Bind -> [Name]
fvBind (Bind n b) = n `delete` nub (fv b)

fvTel :: Tel -> [Name]
fvTel [] = []
fvTel ((_, _X, _A):_As) = fv _A ++ (_X `delete` nub (fvTel _As))

fvRHS :: RHS -> [Name]
fvRHS (MapsTo a) = fv a
fvRHS (Caseless x) = [x]
fvRHS (Split x) = [x]

fvPats :: Pats -> [Name]
fvPats = concatMap (\(i,p) -> fvPat p)

fvPat :: Pat -> [Name]
fvPat (PVar x) = [x]
fvPat (PInacc _) = []
fvPat (PCon _ ps) = fvPats ps

----------------------------------------------------------------------

mv :: Exp -> [Flex]
mv (EVar _) = []
mv EType = []
mv (EInfer _) = []
mv (EGuard x) = [Right x]
mv (EForm _ is) = mvs is
mv (ECon _ _ as) = mvs as
mv (ERed _ as) = mvs as
mv (EMeta x as) = Left x : mvs as
mv (EPi _ _A _B) = mv _A ++ mvBind _B
mv (ELam _ _A b) = mv _A ++ mvBind b
mv (EApp _ a b) = mv a ++ mv b

mvs :: Args -> [Flex]
mvs as = concatMap mv (map snd as)

mvBind :: Bind -> [Flex]
mvBind (Bind _ b) = mv b

----------------------------------------------------------------------

isHole :: MName -> Bool
isHole (MName (MHole _) _) = True
isHole (MName _ _) = False

----------------------------------------------------------------------
