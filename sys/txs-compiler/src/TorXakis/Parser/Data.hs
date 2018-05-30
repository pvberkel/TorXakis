{-# LANGUAGE DeriveDataTypeable     #-}
{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE OverloadedStrings      #-}
{-# LANGUAGE TemplateHaskell        #-}
module TorXakis.Parser.Data
    ( St
    , mkState
    , nodeLoc
    , incId
    , nextId
    , Loc (Loc, PredefLoc, ExtraAut)
    , HasLoc
    , IsVariable
    -- * Name
    , Name
    , toText
    -- * Types of the entities.
    , ADTE
    , CstrE
    , FieldE
    , SortRefE
    , FuncDeclE
    , VarDeclE
    , ExpDeclE
    , VarRefE
    , ChanDeclE
    , ChanRefE
    , ProcDeclE
    , StautDeclE
    , StateDeclE
    , StateRefE
    , PurpDeclE
    , GoalDeclE
    , CnectDeclE
    -- * Declarations.
    -- ** ADT's
    , ADTDecl
    , mkADTDecl
    , adtName
    , constructors
    , CstrDecl
    , mkCstrDecl
    , cstrName
    , cstrFields
    , FieldDecl
    , mkFieldDecl
    , fieldName
    , fieldSort
    -- ** Type declarations
    , OfSort
    , mkOfSort
    , sortRefName
    -- ** Functions
    , FuncDecl
    , mkFuncDecl
    , funcName
    , funcNameL
    , funcParams
    , funcBody
    , funcRetSort
    , VarDecl
    , mkVarDecl
    , varDeclSort
    , IVarDecl
    , mkIVarDecl
    , ivarDeclSort
    , VarRef
    , mkVarRef
    , varName
    -- ** Expressions
    , ExpDecl
    , ExpChild (..)
    , Const (..)
    , expChild
    , childExps
    , mkVarExp
    , mkBoolConstExp
    , mkIntConstExp
    , mkStringConstExp
    , mkRegexConstExp
    , mkLetExpDecl
    , mkITEExpDecl
    , mkFappl
    , mkLetVarDecl
    , expLetVarDecls
    , LetVarDecl
    , varDeclExp
    , letVarDeclSortName
    -- ** Models
    , ModelDecl
    , mkModelDecl
    , modelName
    , modelIns
    , modelOuts
    , modelSyncs
    , modelBExp
    , BExpDecl (..)
    , ActOfferDecl (..)
    , OfferDecl (..)
    , ChanOfferDecl (..)
    , SyncOn (..)
    , chanOfferIvarDecl
    , actOfferDecls
    , offerDecls
    , chanRefOfOfferDecl
    , chanOfferDecls
    , asVarReflLoc
    -- ** Channels
    , ChanDecl
    , mkChanDecl
    , chanDeclName
    , chanDeclSorts
    , ChanRef
    , mkChanRef
    , chanRefName
    -- ** Processes
    , ProcDecl
    , mkProcDecl
    , procDeclName
    , procDeclComps
    , procDeclBody
    , procDeclRetSort
    , procDeclChParams
    , procDeclParams
    , ProcComps
    , procChParams
    , procParams
    , procRetSort
    , procBody
    , procRefName
    , ExitSortDecl (..)
    -- ** State automata
    , StautDecl
    , StautItem (..)
    , StateDecl
    , StateRef
    , StUpdate (..)
    , Transition (..)
    , mkStautDecl
    , mkStateDecl
    , stateDeclName
    , mkStateRef
    , stateRefName
    , stautName
    , asProcDeclLoc
    , stautDeclChParams
    , stautDeclParams
    , stautDeclRetSort
    , stautDeclComps
    , stautDeclStates
    , stautDeclInnerVars
    , stautInitStates
    , stautTrans
    , InitStateDecl (..)
    , mkInitState
    -- ** Purposes
    , PurpDecl
    , mkPurpDecl
    , PurpComps (..)
    , purpDeclName
    , purpDeclIns
    , purpDeclOuts
    , purpDeclSyncs
    , purpDeclGoals
    , TestGoalDecl
    , mkTestGoalDecl
    , testGoalDeclName
    , testGoalDeclBExp
    -- ** Connections
    , CnectDecl
    , CnectType (..)
    , CnectItem (..)
    , CnectItemType (..)
    , CodecItem (..)
    , CodecType (..)
    , mkCnectDecl
    , cnectDeclName
    , cnectDeclType
    , cnectDeclCnectItems
    , cnectDeclCodecs
    -- ** Mappers
    , MapperDecl
    , MapperDeclE
    , mkMapperDecl
    , mapperName
    , mapperIns
    , mapperOuts
    , mapperSyncs
    , mapperBExp
    -- * Location of the entities
    , getLoc
    , loc'
    -- * Parsed definitions
    , ParsedDefs
    , adts
    , funcs
    , consts
    , models
    , chdecls
    , procs
    , emptyPds
    , stauts
    , purps
    , cnects
    , mappers
    )
where

import           Control.Arrow           ((+++), (|||))
import           Control.Lens            (Lens', (^..))
import           Control.Lens.TH         (makeLenses)
import           Data.Data               (Data)
import           Data.Data.Lens          (biplate)
import           Data.Set                (Set)
import           Data.Text               (Text)

import           TorXakis.Compiler.Error

-- | State of the parser.
newtype St = St { nextId :: Int } deriving (Eq, Show)

mkState :: Int -> St
mkState = St

-- | Increment the id of the state.
incId :: St -> St
incId (St i) = St (i + 1)

data ParseTree t c = ParseTree
    { nodeName :: Name t
    , nodeType :: t
    , nodeLoc  :: Loc t
    , child    :: c
    } deriving (Show, Eq, Ord, Data)

newtype Name t = Name { toText :: Text } deriving (Show, Eq, Ord, Data)

nodeNameT :: ParseTree t c -> Text
nodeNameT = toText . nodeName

-- | Location associated to the elements being parsed.
data Loc t
    = Loc
      { -- | Line in which a declaration occurs.
        line   :: Int
        -- | Start column.
      , start  :: Int
        -- | Unique identifier.
      , locUid :: Int
      }
    | PredefLoc
      { -- | Name of the predefined location
        locName :: Text
        -- | Unique identifier.
      , locUid  :: Int
      }
    -- TODO: this is needed only to support the three kind of automata that are
    -- generated per each automaton declaration.
    | ExtraAut Text (Loc t)
    deriving (Show, Eq, Ord, Data)

-- | Change extract the location of the metadata, and change its type from 't'
-- to 'u'. This is useful when defining parsed entities whose locations
-- coincide, like expressions and variable-references or constant-literals.
locFromLoc :: Loc t -> Loc u
locFromLoc (Loc l c i)     = Loc l c i
locFromLoc (PredefLoc n i) = PredefLoc n i
locFromLoc (ExtraAut n l)  = ExtraAut n (locFromLoc l)

class HasLoc a t | a -> t where
    getLoc :: a -> Loc t
    setLoc :: a -> Loc t -> a
    loc' :: Lens' a (Loc t)
    loc' f a = setLoc a <$> f (getLoc a)

instance HasLoc (ParseTree t c) t where
    getLoc = nodeLoc
    setLoc (ParseTree n t _ c) l' = ParseTree n t l' c

-- * Types of entities encountered when parsing.

-- | ADT.
data ADTE = ADTE deriving (Eq, Ord, Show, Data)

-- | Constructor.
data CstrE = CstrE  deriving (Eq, Ord, Show, Data)

-- | Field of a constructor.
data FieldE = FieldE deriving (Eq, Ord, Show, Data)

-- | Reference to an existing (previously defined or primitive) sort.
data SortRefE = SortRefE deriving (Eq, Ord, Show, Data)

-- | Function declaration.
data FuncDeclE = FuncDeclE deriving (Eq, Ord, Show, Data)

-- | An expression
data ExpDeclE = ExpDeclE deriving (Eq, Ord, Show, Data)

-- | A variable declaration.
data VarDeclE = VarDeclE deriving (Eq, Ord, Show, Data)

-- | A variable occurrence in an expression. It is assumed to be a
-- **reference** to an existing variable.
data VarRefE = VarRefE deriving (Eq, Ord, Show, Data)

-- | A constant literal
data ConstLitE = ConstLitE deriving (Eq, Ord, Show, Data)

-- | Channel declaration.
data ChanDeclE = ChanDeclE deriving (Eq, Ord, Show, Data)

-- | Channel  reference.
data ChanRefE = ChanRefE deriving (Eq, Ord, Show, Data)

-- | Model declaration.
data ModelDeclE = ModelDeclE deriving (Eq, Ord, Show, Data)

-- | Process declaration.
data ProcDeclE = ProcDeclE deriving (Eq, Ord, Show, Data)

-- | Process reference. Used at process instantiations.
data ProcRefE = ProcRefE deriving (Eq, Ord, Show, Data)

-- | State automaton declaration.
data StautDeclE = StautDeclE deriving (Eq, Ord, Show, Data)

-- | State declaration.
data StateDeclE = StateDeclE deriving (Eq, Ord, Show, Data)

-- | Reference to a state.
data StateRefE = StateRefE deriving (Eq, Ord, Show, Data)

-- | Purpose declaration.
data PurpDeclE = PurpDeclE deriving (Eq, Ord, Show, Data)

-- | Goal declaration.
data GoalDeclE = GoalDeclE deriving (Eq, Ord, Show, Data)

-- | Connect declaration.
data CnectDeclE = CnectDeclE deriving (Eq, Ord, Show, Data)

-- | Mapper declaration.
data MapperDeclE = MapperDeclE deriving (Eq, Ord, Show, Data)

-- | Parallel operator occurrence in a behavior expression.
data ParOpE = ParOpE deriving (Eq, Ord, Show, Data)

-- | Enable operator occurrence.
data EnableE = EnableE deriving (Eq, Ord, Show, Data)

-- | Disable operator occurrence.
data DisableE = DisableE deriving (Eq, Ord, Show, Data)

-- | Interrupt operator occurrence.
data InterruptE = InterruptE deriving (Eq, Ord, Show, Data)

-- | Choice operator occurrence.
data ChoiceE = ChoiceE deriving (Eq, Ord, Show, Data)

-- | Hide operator occurrence.
data HideE = HideE deriving (Eq, Ord, Show, Data)

-- | Accept operator.
data AcceptE = AcceptE deriving (Eq, Ord, Show, Data)

-- * Types of parse trees.
type ADTDecl   = ParseTree ADTE     [CstrDecl]

mkADTDecl :: Text -> Loc ADTE -> [CstrDecl] -> ADTDecl
mkADTDecl n cs = ParseTree (Name n) ADTE cs

adtName :: ADTDecl -> Text
adtName = nodeNameT

constructors :: ADTDecl -> [CstrDecl]
constructors = child

type CstrDecl  = ParseTree CstrE    [FieldDecl]

mkCstrDecl :: Text -> Loc CstrE -> [FieldDecl] -> CstrDecl
mkCstrDecl n m fs = ParseTree (Name n) CstrE m fs

cstrName :: CstrDecl -> Text
cstrName = nodeNameT

cstrFields :: CstrDecl -> [FieldDecl]
cstrFields = child

type FieldDecl = ParseTree FieldE OfSort

mkFieldDecl :: Text -> Loc FieldE -> OfSort -> FieldDecl
mkFieldDecl n m s = ParseTree (Name n) FieldE m s

fieldName :: FieldDecl -> Text
fieldName = nodeNameT

-- | Get the field of a sort, and the metadata associated to it.
fieldSort :: FieldDecl -> (Text, Loc SortRefE)
fieldSort f = (nodeNameT . child $ f, nodeLoc . child $ f)

-- | Reference to an existing type
type OfSort    = ParseTree SortRefE ()

mkOfSort :: Text -> Loc SortRefE -> OfSort
mkOfSort n m = ParseTree (Name n) SortRefE m ()

sortRefName :: OfSort -> Text
sortRefName = nodeNameT

-- | Components of a function.
data FuncComps = FuncComps
    { funcCompsParams  :: [VarDecl]
    , funcCompsRetSort :: OfSort
    , funcCompsBody    :: ExpDecl
    } deriving (Eq, Show, Ord, Data)

-- | Variable declarations (with an explicit sort).
type VarDecl = ParseTree VarDeclE OfSort

mkVarDecl :: Text -> Loc VarDeclE -> OfSort -> VarDecl
mkVarDecl n l s = ParseTree (Name n) VarDeclE l s

-- | Implicit variable declaration (maybe with a sort associated to it).
type IVarDecl = ParseTree VarDeclE (Maybe OfSort)

mkIVarDecl :: Text -> Loc VarDeclE -> Maybe OfSort -> IVarDecl
mkIVarDecl n l ms = ParseTree (Name n) VarDeclE l ms

ivarDeclSort :: IVarDecl -> Maybe OfSort
ivarDeclSort = child

class IsVariable v where
    -- | Name of a variable
    varName :: v -> Text

instance IsVariable VarDecl where
    varName = nodeNameT

instance IsVariable IVarDecl where
    varName = nodeNameT

varDeclSort :: VarDecl -> (Text, Loc SortRefE)
varDeclSort f = (nodeNameT . child $ f, nodeLoc . child $ f)

-- | Expressions.
type ExpDecl = ParseTree ExpDeclE ExpChild

expChild :: ExpDecl -> ExpChild
expChild = child

data ExpChild = VarRef (Name VarRefE) (Loc VarRefE)
              | ConstLit Const
              -- | A let expression allows to introduce a series of value
              -- bindings of the form:
              --
              -- > x0 = v0, ..., xn = vn
              --
              -- A let expression contains a list of lists that have the form
              -- above. Values declared within one '[LetVarDecl]' list
              -- introduce variable names in parallel (in the sense that one
              -- variable in the list cannot be used in the expressions within
              -- that list). However, values declared in '[LetVarDecl]' lists
              -- can be used in subsequent '[LetVarDecl]' lists. For instance,
              -- the following let expression:
              --
              -- > LET x = 1, y = 5; z = x + y IN ...
              --
              -- Will be parsed to the following list
              --
              -- > [[(x, 1), (y, 5)], [(z, x + y)]]
              --
              -- Here 'x' and 'y' cannot be used in the expressions of the
              -- first list, but it can be used in the expressions of the
              -- second.
              | LetExp [[LetVarDecl]] ExpDecl
              | If ExpDecl ExpDecl ExpDecl
              | Fappl (Name VarRefE) (Loc VarRefE) [ExpDecl] -- ^ Function application. A function is applied
                                                             -- to a list of expressions.
    deriving (Eq, Ord, Show, Data)

data Const = BoolConst Bool
           | IntConst Integer
           | StringConst Text
           | RegexConst Text
           | AnyConst
    deriving (Eq, Show, Ord, Data)

-- | Extract all the let-variable declarations of an expression.
--
expLetVarDecls :: ExpDecl -> [[LetVarDecl]]
expLetVarDecls ParseTree { child = VarRef _ _  } = []
expLetVarDecls ParseTree { child = ConstLit _  } = []
expLetVarDecls ParseTree { child = LetExp vs e } =
    vs ++ expLetVarDecls e ++ concatMap (concatMap (expLetVarDecls . varDeclExp)) vs
expLetVarDecls ParseTree { child = If e0 e1 e2 } =
    expLetVarDecls e0 ++ expLetVarDecls e1 ++ expLetVarDecls e2
expLetVarDecls ParseTree { child = Fappl _ _ exs } =
    concatMap expLetVarDecls exs

-- | Get the child-expressions of an expression.
--
-- TODO: see if you can use traversals instead.
childExps :: ExpDecl -> [ExpDecl]
childExps ParseTree { child = VarRef _ _  }    = []
childExps ParseTree { child = ConstLit _  }    = []
childExps ParseTree { child = LetExp _ e }     = [e]
childExps ParseTree { child = If ex0 ex1 ex2 } = [ex0, ex1, ex2]
childExps ParseTree { child = Fappl _ _ exs }  = exs

mkLetExpDecl :: [[LetVarDecl]] -> ExpDecl -> Loc ExpDeclE -> ExpDecl
mkLetExpDecl vss subEx l = mkExpDecl l (LetExp vss subEx)

mkExpDecl :: Loc ExpDeclE -> ExpChild -> ExpDecl
mkExpDecl l c = ParseTree (Name "") ExpDeclE l c

type LetVarDecl = ParseTree VarDeclE (Maybe OfSort, ExpDecl)

varDeclExp :: LetVarDecl -> ExpDecl
varDeclExp = snd . child

instance IsVariable LetVarDecl where
    varName = nodeNameT

letVarDeclSortName :: LetVarDecl -> Maybe (Text, Loc SortRefE)
letVarDeclSortName vd = do
    srt <- fst . child $ vd
    return (nodeNameT srt, nodeLoc srt)

mkLetVarDecl :: Text -> Maybe OfSort -> ExpDecl -> Loc VarDeclE -> LetVarDecl
mkLetVarDecl n ms subEx m = ParseTree (Name n) VarDeclE m (ms, subEx)

mkITEExpDecl :: Loc ExpDeclE -> ExpDecl -> ExpDecl -> ExpDecl -> ExpDecl
mkITEExpDecl l ex0 ex1 ex2 = mkExpDecl l (If ex0 ex1 ex2)

mkFappl :: Loc ExpDeclE -> Loc VarRefE -> Text -> [ExpDecl] -> ExpDecl
mkFappl le lr n exs = mkExpDecl le (Fappl (Name n) lr exs)

-- | Make a variable expression. The location of the expression will become the
-- location of the variable.
mkVarExp :: Loc ExpDeclE -> Text -> ExpDecl
mkVarExp l n = mkExpDecl l (VarRef (Name n) (locFromLoc l))

mkBoolConstExp :: Loc ExpDeclE -> Bool -> ExpDecl
mkBoolConstExp l b = mkExpDecl l (ConstLit (BoolConst b))

mkIntConstExp :: Loc ExpDeclE -> Integer -> ExpDecl
mkIntConstExp l i = mkExpDecl l (ConstLit (IntConst i))

mkStringConstExp :: Loc ExpDeclE -> Text -> ExpDecl
mkStringConstExp l t = mkExpDecl l (ConstLit (StringConst t))

mkRegexConstExp :: Loc ExpDeclE -> Text -> ExpDecl
mkRegexConstExp l t = mkExpDecl l (ConstLit (RegexConst t))

mkAnyConstExp :: Loc ExpDeclE -> ExpDecl
mkAnyConstExp l = mkExpDecl l (ConstLit AnyConst)

type FuncDecl  = ParseTree FuncDeclE FuncComps

mkFuncDecl :: Text -> Loc FuncDeclE -> [VarDecl] -> OfSort -> ExpDecl -> FuncDecl
mkFuncDecl n l ps s b = ParseTree (Name n) FuncDeclE l (FuncComps ps s b)

funcName :: FuncDecl -> Text
funcName = nodeNameT

funcNameL :: Lens' FuncDecl Text
funcNameL = undefined

funcParams :: FuncDecl -> [VarDecl]
funcParams = funcCompsParams . child

funcBody :: FuncDecl -> ExpDecl
funcBody = funcCompsBody . child

funcRetSort :: FuncDecl -> (Text, Loc SortRefE)
funcRetSort f = ( nodeNameT . funcCompsRetSort . child $ f
                , nodeLoc . funcCompsRetSort . child $ f
                )

instance HasErrorLoc (Loc t) where
    getErrorLoc (Loc l c _)     = ErrorLoc {errorLine = l, errorColumn = c}
    getErrorLoc (PredefLoc n _) = ErrorPredef n
    getErrorLoc (ExtraAut _ l)  = getErrorLoc l

instance HasErrorLoc (ParseTree t c) where
    getErrorLoc pt = ErrorLoc { errorLine = l, errorColumn = c }
        where Loc l c _ = nodeLoc pt

type ModelDecl = ParseTree ModelDeclE ModelComps

-- | Make a model declaration.
mkModelDecl :: Text                -- ^ Model name.
            -> Loc ModelDeclE      -- ^ Location of the model.
            -> [ChanRef]           -- ^ References to input channels.
            -> [ChanRef]           -- ^ References to output channels.
            -> Maybe [Set ChanRef] -- ^ References to sets of synchronized channels.
            -> BExpDecl            -- ^ Behavior expression that defines the model.
            -> ModelDecl
mkModelDecl n l is os ys be =
    ParseTree (Name n) ModelDeclE l (ModelComps is os ys be)

modelName :: ModelDecl -> Text
modelName = nodeNameT

modelIns :: ModelDecl -> [ChanRef]
modelIns = inchs . child

modelOuts :: ModelDecl -> [ChanRef]
modelOuts = outchs . child

modelSyncs :: ModelDecl -> Maybe [Set ChanRef]
modelSyncs = synchs . child

modelBExp :: ModelDecl -> BExpDecl
modelBExp = bexp . child

type ChanRef = ParseTree ChanRefE ()

-- | Make a channel reference.
mkChanRef :: Text         -- ^ Name of the channel that is being referred.
          -> Loc ChanRefE -- ^ Location where the reference took place.
          -> ChanRef
mkChanRef n l = ParseTree (Name n) ChanRefE l ()

chanRefName :: ChanRef -> Text
chanRefName = nodeNameT

data ModelComps = ModelComps
    { inchs  :: [ChanRef]
    , outchs :: [ChanRef]
    , synchs :: Maybe [Set ChanRef]
    , bexp   :: BExpDecl
    } deriving (Eq, Ord, Show, Data)

data BExpDecl
    -- | 'STOP' operator.
    = Stop
    -- | '>->' (action prefix) operator.
    | ActPref  ActOfferDecl BExpDecl
    -- | 'LET' declarations for behavior expressions.
    | LetBExp  [[LetVarDecl]] BExpDecl
    -- | Process instantiation.
    | Pappl (Name ProcRefE) (Loc ProcRefE) [ChanRef] [ExpDecl]
    -- | Parallel operators.
    | Par (Loc ParOpE) SyncOn BExpDecl BExpDecl
    -- | Enable operator.
    | Enable (Loc EnableE) BExpDecl BExpDecl
    -- | 'ACCEPT' operator.
    --
    -- Note that while the parser will allow 'ACCEPT's in arbitrary positions,
    -- the compiler will check that they only occur after an enable operator
    -- ('>>>')
    | Accept (Loc AcceptE) [ChanOfferDecl] BExpDecl
    -- | Disable operator.
    | Disable (Loc DisableE) BExpDecl BExpDecl
    -- | Interrupt operator.
    | Interrupt (Loc InterruptE) BExpDecl BExpDecl
    -- | Choice operator.
    | Choice (Loc ChoiceE) BExpDecl BExpDecl
    -- | Guard operator.
    | Guard ExpDecl BExpDecl
    -- | Hide operator.
    | Hide (Loc HideE) [ChanDecl] BExpDecl
    deriving (Eq, Ord, Show, Data)

-- | Channels to sync on in a parallel operator.
data SyncOn = All              -- ^ Sync on all channels, this is the result of
                               -- parsing '||'
            | OnlyOn [ChanRef] -- ^ Sync only on the given channels. This is
                               -- the result of parsing either '|||' or
                               -- '|[...]|'. Parsing '|||' will result in an
                               -- empty list, meaning that full interleaving is
                               -- allowed.
            deriving (Eq, Ord, Show, Data)

procRefName :: Text -> Name ProcRefE
procRefName = Name

data ActOfferDecl = ActOfferDecl
    { _offers     :: [OfferDecl]
    , _constraint :: Maybe ExpDecl
    } deriving (Eq, Ord, Show, Data)

data OfferDecl = OfferDecl ChanRef [ChanOfferDecl]
    deriving (Eq, Ord, Show, Data)

chanRefOfOfferDecl :: OfferDecl -> ChanRef
chanRefOfOfferDecl (OfferDecl cr _) = cr

-- | Channel offer declarations.
--
-- Note that a receiving action with an explicit type declaration are only
-- needed to simplify the type inference of exit variables used in expressions
-- of the form 'EXIT ? v :: T'.
data ChanOfferDecl = QuestD IVarDecl
                   | ExclD  ExpDecl
    deriving (Eq, Ord, Show, Data)

chanOfferIvarDecl :: ChanOfferDecl -> Maybe IVarDecl
chanOfferIvarDecl (QuestD iv) = Just iv
chanOfferIvarDecl _           = Nothing

-- | Transform a variable declaration into a variable reference. This is used
-- in the case of an implicit variable declaration (which is a reference to
-- itself).
--
-- TODO: does it make sense to have this function instead of just exporting @locFromLoc@.
asVarReflLoc :: Loc VarDeclE -> Loc VarRefE
asVarReflLoc = locFromLoc

-- | Get all the variable declarations introduced by receiving actions of the
-- form 'Ch ? v'.
actOfferDecls :: ActOfferDecl -> [IVarDecl]
actOfferDecls (ActOfferDecl os _) = concatMap offerDecls os

offerDecls :: OfferDecl -> [IVarDecl]
offerDecls (OfferDecl _ cs) = concatMap chanOfferDecls cs

chanOfferDecls :: ChanOfferDecl -> [IVarDecl]
chanOfferDecls (QuestD ivd) = [ivd]
chanOfferDecls (ExclD _)    = []

type VarRef = ParseTree VarRefE ()

mkVarRef :: Text -> Loc VarRefE -> VarRef
mkVarRef n l = ParseTree (Name n) VarRefE l ()

instance IsVariable VarRef where
    varName = nodeNameT

type ChanDecl = ParseTree ChanDeclE [OfSort]

-- | Make a channel declaration.
mkChanDecl :: Text -> Loc ChanDeclE -> [OfSort] -> ChanDecl
mkChanDecl n = ParseTree (Name n) ChanDeclE

chanDeclName :: ChanDecl -> Text
chanDeclName = nodeNameT

chanDeclSorts :: ChanDecl -> [(Text, Loc SortRefE)]
chanDeclSorts ch = zip (fmap nodeNameT . child $ ch)
                       (fmap nodeLoc   . child $ ch)

-- | Process declaration.
type ProcDecl = ParseTree ProcDeclE ProcComps

-- | Components of a process.
data ProcComps = ProcComps
    { procChParams :: [ChanDecl]
    , procParams   :: [VarDecl]
    , procRetSort  :: ExitSortDecl
    , procBody     :: BExpDecl
    } deriving (Eq, Show, Ord, Data)

-- | Make a process declaration.
mkProcDecl :: Text
           -> Loc ProcDeclE
           -> [ChanDecl]
           -> [VarDecl]
           -> ExitSortDecl
           -> BExpDecl
           -> ProcDecl
mkProcDecl n l cs vs e b = ParseTree (Name n) ProcDeclE l (ProcComps cs vs e b)

procDeclName :: ProcDecl -> Text
procDeclName = nodeNameT

procDeclComps :: ProcDecl -> ProcComps
procDeclComps = child

procDeclChParams :: ProcDecl -> [ChanDecl]
procDeclChParams = procChParams . procDeclComps

procDeclParams :: ProcDecl -> [VarDecl]
procDeclParams = procParams . procDeclComps

procDeclRetSort :: ProcDecl -> ExitSortDecl
procDeclRetSort = procRetSort . procDeclComps

procDeclBody :: ProcDecl -> BExpDecl
procDeclBody = procBody . procDeclComps

-- | Possible exit sorts of a process.
data ExitSortDecl = NoExitD
                  | ExitD [OfSort]
                  | HitD
    deriving (Eq, Show, Ord, Data)

-- | State automaton.
type StautDecl = ParseTree StautDeclE StautComps

mkStautDecl :: Text
            -> Loc StautDeclE
            -> [ChanDecl]
            -> [VarDecl]
            -> ExitSortDecl
            -> [StautItem]
            -> StautDecl
mkStautDecl n l cs vs e is = ParseTree (Name n) StautDeclE l (StautComps cs vs e is)

stautName :: StautDecl -> Text
stautName = nodeNameT

-- | Return the location of a state automaton as the location of a process declaration.
asProcDeclLoc :: StautDecl -> Loc ProcDeclE
asProcDeclLoc = locFromLoc . getLoc

-- | Get the channel declarations of a state automaton.
stautDeclChParams :: StautDecl -> [ChanDecl]
stautDeclChParams = stautChParams . child

-- | Get the formal parameters of a state automaton.
stautDeclParams :: StautDecl -> [VarDecl]
stautDeclParams = stautParams . child

-- | Get the return sort of a state automaton.
stautDeclRetSort :: StautDecl -> ExitSortDecl
stautDeclRetSort = stautRetSort . child

-- | Get the components of a state automaton.
stautDeclComps :: StautDecl -> [StautItem]
stautDeclComps = stautComps . child

-- | Components of a state automaton.
data StautComps = StautComps
    { stautChParams :: [ChanDecl]
    , stautParams   :: [VarDecl]
    , stautRetSort  :: ExitSortDecl
    , stautComps    :: [StautItem]
    } deriving (Eq, Show, Ord, Data)

-- | Item of a state automaton.
data StautItem = States [StateDecl]
               | StVarDecl [VarDecl]
               | InitState InitStateDecl
               | Trans [Transition]
    deriving (Eq, Show, Ord, Data)

-- | Extract the states declared in the automaton.
stautDeclStates :: StautDecl -> [StateDecl]
stautDeclStates staut = staut ^.. biplate

-- | Extract the variables declared in the automaton.
stautDeclInnerVars :: StautDecl -> [VarDecl]
stautDeclInnerVars staut = stautComps (child staut) ^.. biplate

-- | Extract the initial states declared in the automaton.
stautInitStates :: StautDecl -> [InitStateDecl]
stautInitStates staut = staut ^.. biplate

-- | Extract the transitions declared in the automaton.
stautTrans :: StautDecl -> [Transition]
stautTrans staut = concat $ staut ^.. biplate

-- | Declaration of an automaton state.
type StateDecl = ParseTree StateDeclE ()

mkStateDecl :: Text -> Loc StateDeclE -> StateDecl
mkStateDecl n l = ParseTree (Name n) StateDeclE l ()

stateDeclName :: StateDecl -> Text
stateDeclName = nodeNameT

-- | Declaration of an initial state.
data InitStateDecl = InitStateDecl StateRef [StUpdate]
    deriving (Eq, Ord, Show, Data)

mkInitState :: StateRef -> [StUpdate] -> StautItem
mkInitState s uds = InitState (InitStateDecl s uds)

-- | Reference to a previously declared automaton state.
type StateRef = ParseTree StateRefE ()

mkStateRef :: Text -> Loc StateRefE -> StateRef
mkStateRef n l = ParseTree (Name n) StateRefE l ()

stateRefName :: StateRef -> Text
stateRefName = nodeNameT

-- | State automaton update.
data StUpdate = StUpdate [VarRef] ExpDecl
    deriving (Eq, Show, Ord, Data)

-- | State automaton transition.
data Transition = Transition StateRef ActOfferDecl [StUpdate] StateRef
    deriving (Eq, Show, Ord, Data)

-- | Purpose declaration.
type PurpDecl = ParseTree PurpDeclE PurpComps

-- | Components of a purpose.
data PurpComps = PurpComps
    { purpIns   :: [ChanRef]
    , purpOuts  :: [ChanRef]
    , purpSyncs :: Maybe [Set ChanRef]
    , goals     :: [TestGoalDecl]
    } deriving (Eq, Show, Data)

type TestGoalDecl = ParseTree GoalDeclE BExpDecl

mkPurpDecl :: Text
           -> Loc PurpDeclE
           -> [ChanRef]
           -> [ChanRef]
           -> Maybe [Set ChanRef]
           -> [TestGoalDecl]
           -> PurpDecl
mkPurpDecl n l is os ys ts =
    ParseTree (Name n) PurpDeclE l (PurpComps is os ys ts)

purpDeclName :: PurpDecl -> Text
purpDeclName = nodeNameT

purpDeclIns :: PurpDecl -> [ChanRef]
purpDeclIns = purpIns . child

purpDeclOuts :: PurpDecl -> [ChanRef]
purpDeclOuts = purpOuts . child

purpDeclSyncs :: PurpDecl -> Maybe [Set ChanRef]
purpDeclSyncs = purpSyncs . child

purpDeclGoals :: PurpDecl -> [TestGoalDecl]
purpDeclGoals = goals . child

mkTestGoalDecl :: Text -> Loc GoalDeclE -> BExpDecl -> TestGoalDecl
mkTestGoalDecl n = ParseTree (Name n) GoalDeclE

testGoalDeclName :: TestGoalDecl -> Text
testGoalDeclName = nodeNameT

testGoalDeclBExp :: TestGoalDecl -> BExpDecl
testGoalDeclBExp = child

-- | 'CNECTDEF' declaration.
type CnectDecl = ParseTree CnectDeclE (CnectType, [CnectItem], [CodecItem])

data CnectType = CTClient | CTServer
    deriving (Eq, Show, Data)

data CnectItem = CnectItem
    { cnectCh   :: ChanRef
    , cnectType :: CnectItemType
    , host      :: Text
    , port      :: Integer
    } deriving (Eq, Show, Data)

data CnectItemType = ChanIn | ChanOut
    deriving (Eq, Ord, Show, Data)

data CodecItem = CodecItem
      { codecOffer   :: OfferDecl
      , codecChOffer :: ChanOfferDecl
      , codecType    :: CodecType
      }
    deriving (Eq, Show, Data)

data CodecType = Decode | Encode
    deriving (Eq, Show, Data)

mkCnectDecl :: Text
            -> Loc CnectDeclE
            -> CnectType
            -> [CnectItem]
            -> [CodecItem]
            -> CnectDecl
mkCnectDecl n l ct is cs = ParseTree (Name n) CnectDeclE l (ct, is, cs)

cnectDeclName :: CnectDecl -> Text
cnectDeclName = nodeNameT

cnectDeclType :: CnectDecl -> CnectType
cnectDeclType = fst3 . child
    where fst3 (f, _, _) = f

cnectDeclCnectItems :: CnectDecl -> [CnectItem]
cnectDeclCnectItems = snd3 . child
    where snd3 (_, s, _) = s

cnectDeclCodecs :: CnectDecl -> [CodecItem]
cnectDeclCodecs = thrd . child
    where thrd (_, _, t) = t

type MapperDecl = ParseTree MapperDeclE ModelComps

mkMapperDecl :: Text
            -> Loc MapperDeclE
            -> [ChanRef]
            -> [ChanRef]
            -> Maybe [Set ChanRef]
            -> BExpDecl
            -> MapperDecl
mkMapperDecl n l is os ys be =
    ParseTree (Name n) MapperDeclE l (ModelComps is os ys be)

mapperName :: MapperDecl -> Text
mapperName = nodeNameT

mapperIns :: MapperDecl -> [ChanRef]
mapperIns = inchs . child

mapperOuts :: MapperDecl -> [ChanRef]
mapperOuts = outchs . child

mapperSyncs :: MapperDecl -> Maybe [Set ChanRef]
mapperSyncs = synchs . child

mapperBExp :: MapperDecl -> BExpDecl
mapperBExp = bexp . child

-- | TorXakis definitions generated by the parser.
data ParsedDefs = ParsedDefs
    { _adts    :: [ADTDecl]
    , _funcs   :: [FuncDecl]
    , _consts  :: [FuncDecl]
    , _models  :: [ModelDecl]
    , _chdecls :: [ChanDecl]
    , _procs   :: [ProcDecl]
    , _stauts  :: [StautDecl]
    , _purps   :: [PurpDecl]
    , _cnects  :: [CnectDecl]
    , _mappers :: [MapperDecl]
    } deriving (Eq, Show, Data)
makeLenses ''ParsedDefs

emptyPds :: ParsedDefs
emptyPds = ParsedDefs [] [] [] [] [] [] [] [] [] []
