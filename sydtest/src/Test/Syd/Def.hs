{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE IncoherentInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

-- | This module defines all the functions you will use to define your test suite.
module Test.Syd.Def
  ( -- * API Functions

    -- ** Declaring tests
    describe,
    it,
    itWithOuter,
    itWithAllOuter,
    specify,
    specifyWithOuter,
    specifyWithAllOuter,

    -- ** Rexports
    module Test.Syd.Def.TestDefM,
    module Test.Syd.Def.Around,
    module Test.Syd.Def.AroundAll,
  )
where

import Control.Monad.RWS.Strict
import qualified Data.Text as T
import GHC.Stack
import Test.QuickCheck.IO ()
import Test.Syd.Def.Around
import Test.Syd.Def.AroundAll
import Test.Syd.Def.TestDefM
import Test.Syd.HList
import Test.Syd.Run
import Test.Syd.SpecDef

-- | Declare a test group
--
-- === Example usage:
--
-- > describe "addition" $ do
-- >     it "adds 3 to 5 to result in 8" $
-- >         3 + 5 `shouldBe` 8
-- >     it "adds 4 to 7 to result in 11" $
-- >         4 + 7 `shouldBe` 11
describe :: String -> TestDefM a b c -> TestDefM a b c
describe s func = censor ((: []) . DefDescribeNode (T.pack s)) func

-- | Declare a test
--
-- __Note: Don't look at the type signature unless you really have to, just follow the examples.__
--
-- === Example usage:
--
-- ==== Tests without resources
--
-- ===== Pure test
--
-- > describe "addition" $
-- >     it "adds 3 to 5 to result in 8" $
-- >         3 + 5 `shouldBe` 8
--
-- ===== IO test
--
-- > describe "readFile and writeFile" $
-- >     it "reads back what it wrote for this example" $ do
-- >         let cts = "hello world"
-- >         let fp = "test.txt"
-- >         writeFile fp cts
-- >         cts' <- readFile fp
-- >         cts' `shouldBe` cts
--
-- ===== Pure Property test
--
-- > describe "sort" $
-- >     it "is idempotent" $
-- >         forAllValid $ \ls ->
-- >             sort (sort ls) `shouldBe` (sort (ls :: [Int]))
--
-- ===== IO Property test
--
-- > describe "readFile and writeFile" $
-- >     it "reads back what it wrote for any example" $ do
-- >         forAllValid $ \fp ->
-- >             forAllValid $ \cts -> do
-- >                 writeFile fp cts
-- >                 cts' <- readFile fp
-- >                 cts' `shouldBe` cts
--
-- ==== Tests with an inner resource
--
-- ===== Pure test
-- ===== IO test
--
-- TODO example with system temp dir
--
-- ===== Pure property test
-- ===== IO property test
--
-- TODO example with system temp dir
it :: forall test. (HasCallStack, IsTest test, Arg1 test ~ HList '[]) => String -> test -> TestDefM '[] (Arg2 test) ()
it s t = do
  sets <- ask
  let testDef =
        TestDef
          { testDefVal = \supplyArgs ->
              runTest
                t
                sets
                ( \func -> supplyArgs func
                ),
            testDefCallStack = callStack
          }
  tell [DefSpecifyNode (T.pack s) testDef ()]

itWithOuter :: (HasCallStack, IsTest test) => String -> test -> TestDefM (Arg1 test ': l) (Arg2 test) ()
itWithOuter s t = do
  sets <- ask
  let testDef =
        TestDef
          { testDefVal = \supplyArgs ->
              runTest
                t
                sets
                (\func -> supplyArgs $ \(HCons arg1 _) arg2 -> func arg1 arg2),
            testDefCallStack = callStack
          }
  tell [DefSpecifyNode (T.pack s) testDef ()]

itWithAllOuter :: (HasCallStack, IsTest test, Arg1 test ~ HList l) => String -> test -> TestDefM l (Arg2 test) ()
itWithAllOuter s t = do
  sets <- ask
  let testDef =
        TestDef
          { testDefVal = \supplyArgs ->
              runTest
                t
                sets
                (\func -> supplyArgs func),
            testDefCallStack = callStack
          }
  tell [DefSpecifyNode (T.pack s) testDef ()]

-- | A synonym for 'it'
specify :: (HasCallStack, IsTest test, Arg1 test ~ HList '[]) => String -> test -> TestDefM '[] (Arg2 test) ()
specify = it

-- | A synonym for 'itWithOuter'
specifyWithOuter :: (HasCallStack, IsTest test) => String -> test -> TestDefM (Arg1 test ': l) (Arg2 test) ()
specifyWithOuter = itWithOuter

-- | A synonym for 'itWithAllOuter'
specifyWithAllOuter :: (HasCallStack, IsTest test, Arg1 test ~ HList l) => String -> test -> TestDefM l (Arg2 test) ()
specifyWithAllOuter = itWithAllOuter
