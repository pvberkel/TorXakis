{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
-----------------------------------------------------------------------------
-- |
-- Module      :  TorXakis.TestFuncData
-- Copyright   :  (c) TNO and Radboud University
-- License     :  BSD3 (see the file license.txt)
-- 
-- Maintainer  :  pierre.vandelaar@tno.nl (ESI)
-- Stability   :  experimental
-- Portability :  portable
--
-- Func Data for Test: 
-- Additional data to ensure termination for QuickCheck
-----------------------------------------------------------------------------
module TorXakis.TestFuncData
(-- * Test Func Data
  TestFuncData
, funcSize
  -- dependencies, yet part of interface
, module TorXakis.TestSortData
)
where
import           TorXakis.FuncSignature
import           TorXakis.TestSortData

-- | Test Func Data
type TestFuncData = TestSortData

-- | Func Size
--   The size of the provided funcSignature as specified by the references to 'TorXakis.FuncSignature' is returned.
--   The size is a measurement of complexity and is indicated by an 'Int'.
--   Note that the function should crash when the context does not contain the 'TorXakis.FuncSignature' and any related 'TorXakis.Sort' references.
funcSize :: RefByFuncSignature -> a -> TestFuncData -> Int
funcSize r _ tfd  = let f = toFuncSignature r in
                      sum (map useSize (returnSort f: args f))
    where
        useSize :: Sort -> Int
        useSize s = 1 + TorXakis.TestSortData.sortSize s tfd