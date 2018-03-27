-- | 

module TorXakis.Compiler.Defs.Sigs where

import           Data.Map (Map)
import           Data.Text (Text)
    
import           SortId (SortId)
import           Sigs    (Sigs, sort, empty, func)
import           VarId   (VarId)

import           TorXakis.Parser.Data
import           TorXakis.Compiler.Data
import           TorXakis.Compiler.Defs.FuncTable

adtDeclsToSigs :: (HasSortIds e, HasFuncIds e, HasFuncDefs e, HasCstrIds e)
               => e -> [ADTDecl] -> CompilerM (Sigs VarId)
-- > data Sigs v = Sigs  { chan :: [ChanId]
-- >                     , func :: FuncTable v
-- >                     , pro  :: [ProcId]
-- >                     , sort :: Map.Map Text SortId
-- >                     } 
-- >
adtDeclsToSigs e ds = do
    ft <- compileToFuncTable e ds
    return $ empty { func = ft }
        

funDeclsToSigs :: (HasSortIds e, HasFuncIds e, HasFuncDefs e, HasCstrIds e)
               => e -> [FuncDecl] -> CompilerM (Sigs VarId)
funDeclsToSigs e ds = do
    ft <- funcDeclsToFuncTable e ds
    return $ empty { func = ft }              

sortsToSigs :: Map Text SortId -> Sigs VarId
sortsToSigs sm = empty { sort = sm }