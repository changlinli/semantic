{-# LANGUAGE MultiParamTypeClasses, Rank2Types, TypeFamilies, TypeOperators, UndecidableInstances #-}
module Control.Abstract.Value where

import Control.Abstract.Addressable
import Control.Abstract.Analysis
import Data.Abstract.Environment
import Data.Abstract.FreeVariables
import Data.Abstract.Type as Type
import Data.Abstract.Value as Value
import Data.Bitraversable
import Data.Scientific (Scientific, fromFloatDigits, toRealFloat)
import Prelude hiding (fail)
import Prologue

-- TODO: move this useful projection function elsewhere
au :: (i :< is, j :< js) => (Union is a, Union js b) -> Maybe (i a, j b)
au = bitraverse prj prj

-- | A 'Monad' abstracting the evaluation of (and under) binding constructs (functions, methods, etc).
--
--   This allows us to abstract the choice of whether to evaluate under binders for different value types.
class (MonadAnalysis term value m, Show value) => MonadValue term value m where
  -- | Construct an abstract unit value.
  --   TODO: This might be the same as the empty tuple for some value types
  unit :: m value

  -- | Construct an abstract integral value.
  integer :: Prelude.Integer -> m value

  -- | Lift a unary operator over a 'Num' to a function on 'value's.
  liftNumeric  :: (forall a . Num a => a -> a)
               -> (value -> m value)

  -- | Lift a pair of binary operators to a function on 'value's.
  --   You usually pass the same operator as both arguments, except in the cases where
  --   Haskell provides different functions for integral and fractional operations, such
  --   as division, exponentiation, and modulus.
  liftNumeric2 :: (forall a . (Real a, Floating a) => a -> a -> a)
               -> (forall b . Integral b           => b -> b -> b)
               -> (value -> value -> m value)


  liftComparison :: (forall a . Ord a => a -> a -> Bool)
                 -> (value -> value -> m value)

  -- | Construct an abstract boolean value.
  boolean :: Bool -> m value

  -- | Construct an abstract string value.
  string :: ByteString -> m value

  -- | Construct a floating-point value.
  float :: Scientific -> m value

  -- | Construct an N-ary tuple of multiple (possibly-disjoint) values
  multiple :: [value] -> m value

  -- | Construct an abstract interface value.
  interface :: value -> m value

  -- | Eliminate boolean values. TODO: s/boolean/truthy
  ifthenelse :: value -> m a -> m a -> m a

  -- | Evaluate an abstraction (a binder like a lambda or method definition).
  abstract :: [Name] -> Subterm term (m value) -> m value
  -- | Evaluate an application (like a function call).
  apply :: value -> [Subterm term (m value)] -> m value

  -- | Extract the environment from an interface value.
  environment :: value -> m (EnvironmentFor value)

-- | Attempt to extract a 'Prelude.Bool' from a given value.
toBool :: MonadValue term value m => value -> m Bool
toBool v = ifthenelse v (pure True) (pure False)

-- | As with 'toBool', except from a given 'Subterm'.
evalToBool :: MonadValue term value m => Subterm t (m value) -> m Bool
evalToBool = subtermValue >=> toBool

-- | Construct a 'Value' wrapping the value arguments (if any).
instance ( MonadAddressable location (Value location term) m
         , MonadAnalysis term (Value location term) m
         , Show location
         , Show term
         )
         => MonadValue term (Value location term) m where

  unit    = pure . injValue $ Value.Unit
  integer = pure . injValue . Integer
  boolean = pure . injValue . Boolean
  string  = pure . injValue . Value.String
  float   = pure . injValue . Value.Float
  multiple vals =
    pure . injValue $ Value.Tuple vals

  interface v = injValue . Value.Interface v <$> getGlobalEnv

  ifthenelse cond if' else'
    | Just (Boolean b) <- prjValue cond = if b then if' else else'
    | otherwise = fail ("not defined for non-boolean conditions: " <> show cond)

  liftNumeric f arg
    | Just (Integer i)     <- prj arg = pure . inj . Integer     $ f i
    | Just (Value.Float i) <- prj arg = pure . inj . Value.Float $ f i
    | otherwise = fail "Invalid operand to liftNumeric"

  liftNumeric2 f g left right
    | Just (Integer i, Integer j)         <- au pair = pure . inj . Integer $ g i j
    | Just (Integer i, Value.Float j)     <- au pair = pure . inj . float   $ f (fromIntegral i) (munge j)
    | Just (Value.Float i, Value.Float j) <- au pair = pure . inj . float   $ f (munge i) (munge j)
    | Just (Value.Float i, Integer j)     <- au pair = pure . inj . float   $ f (munge i) (fromIntegral j)
    | otherwise = fail "Invalid operands to liftNumeric2"
      where
        -- Yucky hack to work around the lack of a Floating instance for Scientific.
        -- This may possibly lose precision, but there's little we can do about that.
        munge :: Scientific -> Double
        munge = toRealFloat
        float :: Double -> Value.Float a
        float = Value.Float . fromFloatDigits
        pair = (left, right)

  liftComparison f left right
    | Just (Integer i, Integer j)           <- au pair = boolean (f i j)
    | Just (Integer i, Value.Float j)       <- au pair = boolean (f (fromIntegral i) j)
    | Just (Value.Float i, Integer j)       <- au pair = boolean (f i (fromIntegral j))
    | Just (Value.Float i, Value.Float j)   <- au pair = boolean (f i j)
    | Just (Value.String i, Value.String j) <- au pair = boolean (f i j)
    | Just (Boolean i, Boolean j)           <- au pair = boolean (f i j)
    | Just (Value.Unit, Value.Unit)         <- au pair = boolean True
    | otherwise = fail "Type error: invalid arguments to liftComparison"
      where pair = (left, right)

  abstract names (Subterm body _) = injValue . Closure names body <$> askLocalEnv

  apply op params = do
    Closure names body env <- maybe (fail ("expected a closure, got: " <> show op)) pure (prjValue op)
    bindings <- foldr (\ (name, param) rest -> do
      v <- subtermValue param
      a <- alloc name
      assign a v
      envInsert name a <$> rest) (pure env) (zip names params)
    localEnv (mappend bindings) (evaluateTerm body)

  environment v
    | Just (Interface _ env) <- prjValue v = pure env
    | otherwise                            = pure mempty

-- | Discard the value arguments (if any), constructing a 'Type.Type' instead.
instance (Alternative m, MonadAnalysis term Type m, MonadFresh m) => MonadValue term Type m where
  abstract names (Subterm _ body) = do
    (env, tvars) <- foldr (\ name rest -> do
      a <- alloc name
      tvar <- Var <$> fresh
      assign a tvar
      (env, tvars) <- rest
      pure (envInsert name a env, tvar : tvars)) (pure mempty) names
    ret <- localEnv (mappend env) body
    pure (Product tvars :-> ret)

  unit      = pure Type.Unit
  integer _ = pure Int
  boolean _ = pure Bool
  string _  = pure Type.String
  float _   = pure Type.Float
  multiple  = pure . Type.Product
  -- TODO
  interface = undefined

  ifthenelse cond if' else' = unify cond Bool *> (if' <|> else')

  liftNumeric _ Type.Float = pure Type.Float
  liftNumeric _ Int        = pure Int
  liftNumeric _ _          = fail "Invalid type in unary numeric operation"

  liftNumeric2 _ _ left right = case (left, right) of
    (Type.Float, Int) -> pure Type.Float
    (Int, Type.Float) -> pure Type.Float
    _                 -> unify left right

  -- TODO: this probably isn't right
  liftComparison _ left right = unify left right

  apply op params = do
    tvar <- fresh
    paramTypes <- traverse subtermValue params
    _ :-> ret <- op `unify` (Product paramTypes :-> Var tvar)
    pure ret

  -- TODO
  environment = undefined
