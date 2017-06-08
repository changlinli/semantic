{-# LANGUAGE DataKinds, DeriveAnyClass, DeriveGeneric #-}
module Data.Syntax.Literal where

import Data.Align.Generic
import Data.Functor.Classes.Eq.Generic
import Data.Functor.Classes.Show.Generic
import Data.Functor.Union
import GHC.Generics
import Prologue hiding (Set)

-- Boolean

newtype Boolean a = Boolean Bool
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

true :: Boolean a
true = Boolean True

false :: Boolean a
false = Boolean False

instance Eq1 Boolean where liftEq = genericLiftEq
instance Show1 Boolean where liftShowsPrec = genericLiftShowsPrec


-- Numeric

-- | A literal integer of unspecified width. No particular base is implied.
newtype Integer a = Integer { integerContent :: ByteString }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Data.Syntax.Literal.Integer where liftEq = genericLiftEq
instance Show1 Data.Syntax.Literal.Integer where liftShowsPrec = genericLiftShowsPrec

-- TODO: Should IntegerLiteral hold an Integer instead of a ByteString?
-- TODO: Do we care about differentiating between hex/octal/decimal/binary integer literals?
-- TODO: Consider a Numeric datatype with FloatingPoint/Integral/etc constructors.

-- | A literal float of unspecified width.
newtype Float a = Float { floatContent :: ByteString }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Data.Syntax.Literal.Float where liftEq = genericLiftEq
instance Show1 Data.Syntax.Literal.Float where liftShowsPrec = genericLiftShowsPrec


data Range a = Range { rangeStart :: !a, rangeEnd :: !a }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Range where liftEq = genericLiftEq
instance Show1 Range where liftShowsPrec = genericLiftShowsPrec


-- Strings, symbols

newtype String a = String { stringElements :: [Union '[InterpolationElement, TextElement] a] }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 String where liftEq = genericLiftEq
instance Show1 String where liftShowsPrec = genericLiftShowsPrec

-- TODO: Should string literal bodies include escapes too?

-- | An interpolation element within a string literal.
newtype InterpolationElement a = InterpolationElement { interpolationBody :: a }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 InterpolationElement where liftEq = genericLiftEq
instance Show1 InterpolationElement where liftShowsPrec = genericLiftShowsPrec


-- | A sequence of textual contents within a string literal.
newtype TextElement a = TextElement { textElementContent :: ByteString }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 TextElement where liftEq = genericLiftEq
instance Show1 TextElement where liftShowsPrec = genericLiftShowsPrec

data Null a = Null
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Null where liftEq = genericLiftEq
instance Show1 Null where liftShowsPrec = genericLiftShowsPrec

newtype Symbol a = Symbol { symbolContent :: ByteString }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Symbol where liftEq = genericLiftEq
instance Show1 Symbol where liftShowsPrec = genericLiftShowsPrec

-- TODO: Heredoc-style string literals?
-- TODO: Character literals.
-- TODO: Regular expressions.


-- Collections

newtype Array a = Array { arrayElements :: [a] }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Array where liftEq = genericLiftEq
instance Show1 Array where liftShowsPrec = genericLiftShowsPrec


newtype Hash a = Hash { hashElements :: [a] }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Hash where liftEq = genericLiftEq
instance Show1 Hash where liftShowsPrec = genericLiftShowsPrec


data KeyValue a = KeyValue { key :: !a, value :: !a }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 KeyValue where liftEq = genericLiftEq
instance Show1 KeyValue where liftShowsPrec = genericLiftShowsPrec


newtype Tuple a = Tuple { tupleContents :: [a]}
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Tuple where liftEq = genericLiftEq
instance Show1 Tuple where liftShowsPrec = genericLiftShowsPrec


newtype Set a = Set { setElements :: [a] }
  deriving (Eq, Foldable, Functor, GAlign, Generic1, Show, Traversable)

instance Eq1 Set where liftEq = genericLiftEq
instance Show1 Set where liftShowsPrec = genericLiftShowsPrec

-- TODO: Object literals as distinct from hash literals? Or coalesce object/hash literals into “key-value literals”?
-- TODO: Function literals (lambdas, procs, anonymous functions, what have you).
-- TODO: Regexp literals.
