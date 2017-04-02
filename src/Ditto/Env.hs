module Ditto.Env where
import Ditto.Syntax
import Ditto.Monad
import Ditto.Throw
import Data.List
import Control.Monad.State

----------------------------------------------------------------------

addSig :: Sigma -> TCM ()
addSig s = do
  state@DittoS {env = env} <- get
  when (s `elem` env) $ throwGenErr $
    "Element being added already exists in the environment: " ++ show s
  put state { env = snoc env s }

updateSig :: Sigma -> Sigma -> TCM ()
updateSig s s' = do
  state@DittoS {env = env} <- get
  case break (== s) env of
    (env1, _:env2) -> put state { env = env1 ++ s':env2 }
    (env1, []) -> throwGenErr $
      "Element being updated does not exist in the environment: " ++ show s

----------------------------------------------------------------------

genMetaPi :: Tel -> Icit -> TCM Exp
genMetaPi _As i = do
  acts <- getActs
  _X <- addMeta MInfer acts _As EType
  let _A = EMeta _X (varArgs _As)
  x <- gensymInacc
  let _Bs = snoc _As (i, x, _A)
  _Y <- addMeta MInfer acts _Bs EType
  let _B = EMeta _Y (varArgs _Bs)
  return (EPi i _A (Bind x _B))

genMeta :: MKind -> TCM (Exp, Exp)
genMeta m = do
  acts <- getActs
  _As <- getCtx
  _X <- addMeta MInfer acts _As EType
  let _B = EMeta _X (varArgs _As)
  x <- addMeta m acts _As _B
  let b = EMeta x (varArgs _As)
  return (b, _B)

addMeta :: MKind -> Acts -> Tel -> Exp -> TCM MName
addMeta k acts ctx _A = do
  x <- gensymMeta k
  insertMeta x acts ctx _A
  return x

solveMeta :: MName -> Exp -> TCM ()
solveMeta x a = insertSol x a

----------------------------------------------------------------------

addDef :: Name -> Exp -> Exp -> TCM ()
addDef x a _A = do
  xs <- allNames
  when (elem x xs) $ throwGenErr
    $ "Definition name already exists in the environment: " ++ show x
  insertDef x a _A

genGuard :: Exp -> Exp -> Prob -> TCM Exp
genGuard a _A p = do
  _As <- getCtx
  x <- gensymGuard
  insertProb x p
  insertGuard x (lams _As a) (pis _As _A)
  return $ apps (EGuard x) (varArgs _As)

----------------------------------------------------------------------

addForm :: PName -> Tel -> TCM ()
addForm x _Is = do
  env <- getEnv
  when (any (isPNamed x) env) $ throwGenErr
    $ "Type former name already exists in the environment: " ++ show x
  addSig (DForm x [] _Is)
  addDef (pname2name x) (lams _Is (EForm x (varArgs _Is))) (formType _Is)

addCon :: (PName, Tel, PName, Args) -> TCM ()
addCon (x, _As, _X, _Is) = do
  env <- getEnv
  when (any (isPNamed x) env) $ throwGenErr
    $ "Constructor name already exists in the environment: " ++ show x
  case find (isPNamed _X) env of
      Just s@(DForm _ cs _Js) -> do
        updateSig s (DForm _X (snoc cs (x, Con _As _Is)) _Js)
        addDef (pname2name x) (lams _As (ECon _X x (varArgs _As))) (conType _As _X _Is)
      _ -> throwGenErr $
        "Datatype does not exist in the environment: " ++ show _X

----------------------------------------------------------------------

addRed :: PName -> Tel -> Exp -> TCM ()
addRed x _As _B = do
  env <- getEnv
  when (any (isPNamed x) env) $ throwGenErr
    $ "Reduction name already exists in the environment: " ++ show x
  insertRed x _As _B
  addSig (DRed x [] _As _B)
  addDef (pname2name x) (lams _As (ERed x (varArgs _As))) (pis _As _B)

addClauses :: PName -> Clauses -> TCM ()
addClauses x cs = do
  env <- getEnv
  case find (isPNamed x) env of
    Just s@(DRed _ [] _As _B) -> do
      insertClauses x cs
      updateSig s (DRed x cs _As _B)
    Just s@(DRed _ _ _As _B) -> throwGenErr $
      "Reduction already contains clauses: " ++ show x
    _ -> throwGenErr $
      "Reduction does not exist in the environment: " ++ show x

----------------------------------------------------------------------
