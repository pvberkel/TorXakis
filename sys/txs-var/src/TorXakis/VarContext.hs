{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
-----------------------------------------------------------------------------
-- |
-- Module      :  VarContext
-- Copyright   :  (c) TNO and Radboud University
-- License     :  BSD3 (see the file license.txt)
--
-- Maintainer  :  pierre.vandelaar@tno.nl (Embedded Systems Innovation by TNO)
-- Stability   :  experimental
-- Portability :  portable
--
-- Context for Variables.
-----------------------------------------------------------------------------
module TorXakis.VarContext
( -- * Context
  -- ** Variable Context class
  VarContext (..)
)
where
import           TorXakis.Error
import           TorXakis.Name
import           TorXakis.Sort ( SortContext(..) )
import           TorXakis.VarDef

-- | A Variable Context instance contains all definitions to work with sorts and variables
    -- TODO? addVarsDecl function -> don't need to check uniqueness of added variables (still need to check for undefined sorts).
class SortContext a => VarContext a where
    -- | Refers the provided VarDef name to a VarDef in the context?
    memberVar :: a -> RefByName VarDef -> Bool
    -- | lookup VarDef
    lookupVar :: a -> RefByName VarDef -> Maybe VarDef
    -- | All VarDef elements in the context
    elemsVar :: a -> [VarDef]
    -- | Add variables to variable context.
    --   A variable context is returned when the following constraints are satisfied:
    --
    --   * The names of the added variables are distinct
    --
    --   * All sorts are known
    --
    --   Otherwise an error is returned. The error reflects the violations of any of the aforementioned constraints.
    -- Note: added variables might hide previously defined variables.
    -- Note: the order of the variables is not relevant.
    addVars :: a -> [VarDef] -> Either Error a
    -- | Replace variables of variable context.
    --   A variable context is returned when the following constraints are satisfied:
    --
    --   * The names of the variables are distinct
    --
    --   * All sorts are known
    --
    --   Otherwise an error is returned. The error reflects the violations of any of the aforementioned constraints.
    replaceVars :: a -> [VarDef] -> Either Error a
