module Ditto.Env where
import Ditto.Syntax
import Ditto.Monad
import Ditto.Sub
import Data.List
import Control.Monad.State
import Control.Monad.Reader
import Control.Monad.Identity
import Control.Monad.Except

----------------------------------------------------------------------

addSig :: Sigma -> TCM ()
addSig s = do
  state@DittoS {env = env} <- get
  when (s `elem` env) $ throwError $
    "Element being added already exists in the environment: " ++ show s
  put state { env = s : env }

updateSig :: Sigma -> Sigma -> TCM ()
updateSig s s' = do
  state@DittoS {env = env} <- get
  case break (== s) env of
    (env1, _:env2) -> put state { env = env1 ++ s':env2 }
    (env1, []) -> throwError $
      "Element being updated does not exist in the environment: " ++ show s

addDef :: Name -> Exp -> Exp -> TCM ()
addDef x a _A = do
  env <- getEnv
  when (any (isNamed x) env) $ throwError
    $ "Definition name already exists in the environment: " ++ show x
  addSig (Def x a _A)

----------------------------------------------------------------------

genMeta :: TCM (Exp, Exp)
genMeta = do
  _As <- reverse <$> getCtx
  _X <- addMeta _As Type
  let _B = Meta _X (varNames _As)
  x <- addMeta _As _B
  let b = Meta x (varNames _As)
  return (b, _B)

addMeta :: Tel -> Exp -> TCM MName
addMeta _As _B = do
  x <- gensymMeta
  addSig (DMeta x Nothing _As _B)
  return x

solveMeta :: MName -> Exp -> TCM ()
solveMeta x a = do
  env <- getEnv
  case find (isMNamed x) env of
    Just s@(DMeta _ Nothing _As _B) -> do
      updateSig s (DMeta x (Just a) _As _B)
    Just s@(DMeta _ _ _ _) -> throwError $
      "Metavariable is already defined: " ++ show x
    _ -> throwError $
      "Metavariable does not exist in the environment: " ++ show x

----------------------------------------------------------------------

addForm :: PName -> Tel -> TCM ()
addForm x _Is = do
  env <- getEnv
  when (any (isPNamed x) env) $ throwError
    $ "Type former name already exists in the environment: " ++ show x
  addSig (DForm x _Is)
  addDef (pname2name x) (lams _Is (Form x (varNames _Is))) (formType _Is)

addCon :: (PName, Tel, PName, [Exp]) -> TCM ()
addCon (x, _As, _X, _Is) = do
  env <- getEnv
  when (any (isPNamed x) env) $ throwError
    $ "Constructor name already exists in the environment: " ++ show x
  addSig (DCon x _As _X _Is)
  addDef (pname2name x) (lams _As (Con x (varNames _As))) (pis _As $ Form _X _Is)

addRedType :: PName -> Tel -> Exp -> TCM ()
addRedType x _As _B = do
  env <- getEnv
  when (any (isPNamed x) env) $ throwError
    $ "Reduction name already exists in the environment: " ++ show x
  addSig (DRed x [] _As _B)
  addDef (pname2name x) (lams _As (Red x (varNames _As))) (pis _As _B)

addRedClauses :: PName -> [CheckedClause] -> TCM ()
addRedClauses x cs = do
  env <- getEnv
  case find (isPNamed x) env of
    Just s@(DRed _ [] _As _B) -> do
      updateSig s (DRed x cs _As _B)
    Just s@(DRed _ _ _As _B) -> throwError $
      "Reduction already contains clauses: " ++ show x
    _ -> throwError $
      "Reduction does not exist in the environment: " ++ show x

----------------------------------------------------------------------
