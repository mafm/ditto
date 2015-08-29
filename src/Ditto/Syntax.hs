module Ditto.Syntax where

----------------------------------------------------------------------

data Verbosity = Normal | Verbose
  deriving (Show, Read, Eq)

----------------------------------------------------------------------

data Name = Name String (Maybe Integer)
  deriving (Read, Eq)

instance Show Name where
  show (Name x Nothing) = x
  show (Name x (Just n)) = x ++ "$" ++ show n

s2n :: String -> Name
s2n x = Name x Nothing

uniqName :: Name -> Integer -> Name
uniqName (Name x _) n = Name x (Just n)

----------------------------------------------------------------------

newtype PName = PName String
  deriving (Read, Eq)

instance Show PName where
  show (PName x) = "#" ++ x

pname2name :: PName -> Name
pname2name (PName x) = Name x Nothing

name2pname :: Name -> Maybe PName
name2pname (Name x Nothing) = Just (PName x)
name2pname _ = Nothing

----------------------------------------------------------------------

type Cons = [(PName, Exp)]

data Stmt =
    SDef Name Exp Exp
  | SData PName Exp Cons
  | SDefn PName Exp [Clause]
  deriving (Show, Read, Eq)

data Exp =
    Type | Pi Exp Bind | Lam Exp Bind
  | Form PName [Exp] | Con PName [Exp]
  | Var Name | Exp :@: Exp | Red PName [Exp]
  deriving (Show, Read, Eq)

data Bind = Bind Name Exp
  deriving (Show, Read, Eq)

type Env = [Sigma]
type Tel = [(Name, Exp)]
type Sub = [(Name, Exp)]
type PSub = [(Name, Pat)]
type Clause = ([Pat], RHS)
type CheckedClause = (Tel, [Pat], RHS)

data RHS = Prog Exp | Caseless Name
  deriving (Show, Read, Eq)

data Sigma =
    Def Name Exp Exp
  | DForm PName Tel
  | DCon PName Tel PName [Exp]
  | DRed PName [CheckedClause] Tel Exp
  deriving (Show, Read, Eq)

data Pat = PVar Name | Inacc (Maybe Exp) | PCon PName [Pat]
  deriving (Show, Read, Eq)

----------------------------------------------------------------------

names :: Tel -> [Name]
names = map fst

varNames :: Tel -> [Exp]
varNames = map (Var . fst)

pvarNames :: Tel -> [Pat]
pvarNames = map (PVar . fst)

types :: Tel -> [Exp]
types = map snd

pis :: Tel -> Exp -> Exp
pis = flip $ foldr (\ (x , _A) _B -> Pi _A (Bind x _B))

lams :: Tel -> Exp -> Exp
lams = flip $ foldr (\ (x , _A) _B -> Lam _A (Bind x _B))

apps :: Exp -> [Exp] -> Exp
apps x xs = foldl (:@:) x xs

----------------------------------------------------------------------

formType :: Tel -> Exp
formType _Is = pis _Is Type

conType :: Tel -> PName -> [Exp] -> Exp
conType _As _X _Is = pis _As (Form _X _Is)

----------------------------------------------------------------------
