{-# LANGUAGE TypeFamilies, TypeOperators, UndecidableInstances #-}
module Control.Effect.NonDet
( MonadNonDet(..)
, NonDet
) where

import Control.Monad.Effect.Internal
import Control.Monad.Effect.NonDet as NonDet
import Prologue

-- | 'Monad's offering local isolation of nondeterminism effects.
class (Alternative m, Monad m) => MonadNonDet m where
  -- | Run a computation, gathering any nondeterministically produced results into a single 'Monoid'al value.
  gather :: Monoid b
         => (a -> b) -- ^ A function constructing a 'Monoid'al value from a single computed result. This might typically be @unit@ (for @Reducer@s), 'pure' (for 'Applicative's), or some similar singleton constructor.
         -> m a      -- ^ The computation to run locally-nondeterministically.
         -> m b      -- ^ A _deterministic_ computation producing the 'Monoid'al accumulation of the _locally-nondeterministic_ result values.

-- | Effect stacks containing 'NonDet' offer a 'MonadNonDet' instance which implements 'gather' by interpreting the requests for nondeterminism locally, without removing 'NonDet' from the stack—i.e. the _capacity_ for nondeterminism is still present in the effect stack, but any local nondeterminism has been applied.
instance (NonDet :< fs) => MonadNonDet (Eff fs) where
  gather = NonDet.gather
