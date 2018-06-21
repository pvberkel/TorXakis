{-# LANGUAGE DataKinds        #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies     #-}
module TorXakis.Compiler.Defs.ModelDef where

import           Control.Monad.Error.Class          (liftEither)
import           Data.List                          (nub, sortBy)
import           Data.Map                           (Map)
import qualified Data.Map                           as Map
import           Data.Ord                           (compare)
import           Data.Set                           (Set)
import qualified Data.Set                           as Set
import           Data.Text                          (Text)

import           ChanId                             (ChanId, name, unid)
import           FuncDef                            (FuncDef)
import           FuncId                             (FuncId)
import           FuncTable                          (Handler, Signature)
import           ProcId                             (ExitSort (Exit, NoExit),
                                                     ProcId)
import           SortId                             (SortId)
import           StdTDefs                           (chanIdExit)
import           TxsDefs                            (ModelDef (ModelDef),
                                                     ProcDef)
import           VarId                              (VarId)

import           TorXakis.Compiler.Data
import           TorXakis.Compiler.Defs.BehExprDefs
import           TorXakis.Compiler.Maps
import           TorXakis.Compiler.Maps.DefinesAMap
import           TorXakis.Compiler.Maps.VarRef
import           TorXakis.Compiler.MapsTo
import           TorXakis.Compiler.ValExpr.FuncDef
import           TorXakis.Compiler.ValExpr.SortId
import           TorXakis.Compiler.ValExpr.VarId
import           TorXakis.Parser.Data

modelDeclToModelDef :: ( MapsTo Text SortId mm
                       , MapsTo Text (Loc ChanDeclE) mm -- Needed because channels are declared outside the model.
                       , MapsTo (Loc ChanDeclE) ChanId mm -- Also needed because channels are declared outside the model
                       , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
                       , MapsTo (Loc FuncDeclE) (Signature, Handler VarId) mm
                       , MapsTo ProcId () mm
                       , MapsTo (Loc VarDeclE) SortId mm
                       , MapsTo (Loc VarDeclE) VarId mm
                       , In (Loc FuncDeclE, Signature) (Contents mm) ~ 'False
                       , In (Loc ChanRefE, Loc ChanDeclE) (Contents mm) ~ 'False )
                    => mm -> ModelDecl -> CompilerM ModelDef
modelDeclToModelDef mm md = do
    -- Map the channel references to the places in which they are declared.
    chDecls <- getMap mm md :: CompilerM (Map (Loc ChanRefE) (Loc ChanDeclE))
    -- Add the channel declaration introduced by the hide operator.
    modelChIds <- getMap mm md :: CompilerM (Map (Loc ChanDeclE) ChanId)
    let mm' = chDecls :& (modelChIds <.+> mm)
    -- Infer the variable types of the expression:
    let fshs :: Map (Loc FuncDeclE) (Signature, Handler VarId)
        fshs = innerMap mm
        fss = fst <$> fshs
    bTypes <- Map.fromList <$> inferVarTypes (fss :& mm') (modelBExp md)
    bvIds  <- Map.fromList <$> mkVarIds bTypes (modelBExp md)
    let mm'' = bTypes <.+> (bvIds <.+> mm')
    evds <- liftEither $ varDefsFromExp mm'' md

    ins  <- Set.fromList <$> traverse (lookupChId mm') (getLoc <$> modelIns md)
    outs <- Set.fromList <$> traverse (lookupChId mm') (getLoc <$> modelOuts md)
    let
        -- Channels used in the model.
        usedChIds :: [Set ChanId]
        usedChIds = fmap Set.singleton (sortByUnid . nub . Map.elems $ usedChIdMap mm')
        -- Sort the channels by its id, since we have to comply with the current TorXakis compiler.
        sortByUnid :: [ChanId] -> [ChanId]
        sortByUnid = sortBy cmpChUnid
            where
              cmpChUnid c0 c1 = unid c0 `compare` unid c1
    syncs <- maybe (return usedChIds)
                   (traverse (chRefsToChIdSet mm'))
                   (modelSyncs md)
    let
        insyncs  = filter (`Set.isSubsetOf` ins) syncs
        outsyncs = filter (`Set.isSubsetOf` outs) syncs
        -- TODO: construct this, once you know the exit sort of the behavior expression `be`.
        -- errsyncs = ...

    be   <- toBExpr mm'' evds (modelBExp md)
    eSort <- exitSort (fss :& mm'') (modelBExp md)
    let
        splsyncs = case eSort of
            NoExit  -> []
            Exit [] -> [ Set.singleton chanIdExit ]
            _       -> [] -- TODO: Ask jan, what should we return in this case? Error?

    return $ ModelDef insyncs outsyncs splsyncs be

-- | Compile a set of channel references to the set of channel id's they refer
-- to.
chRefsToChIdSet :: ( MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
                   , MapsTo (Loc ChanDeclE) ChanId mm )
                => mm -> Set ChanRef -> CompilerM (Set ChanId)
chRefsToChIdSet mm = fmap Set.fromList . chRefsToIds mm . Set.toList
