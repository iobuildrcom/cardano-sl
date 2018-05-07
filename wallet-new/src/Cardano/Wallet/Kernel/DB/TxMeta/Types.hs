-- | Transaction metadata conform the wallet specification
module Cardano.Wallet.Kernel.DB.TxMeta.Types (
    -- * Transaction metadata
    TxMeta(..)
    -- ** Lenses
  , txMetaId
  , txMetaAmount
  , txMetaInputs
  , txMetaOutputs
  , txMetaCreationAt
  , txMetaIsLocal
  , txMetaIsOutgoing

  -- * Domain-specific errors
  , TxMetaStorageError (..)
  , InvariantViolation (..)
  ) where

import           Universum

import           Control.Lens.TH (makeLenses)
import qualified Data.List as List
import           Data.Text.Buildable (build)
import           Formatting (bprint, shown, (%))
import           Pos.Crypto (shortHashF)
import           Test.QuickCheck (Arbitrary (..), Gen)

import           Pos.Arbitrary.Core ()
import qualified Pos.Core as Core

{-------------------------------------------------------------------------------
  Transaction metadata
-------------------------------------------------------------------------------}

-- | Transaction metadata
--
-- NOTE: This does /not/ live in the acid-state database (and consequently
-- does not need a 'SafeCopy' instance), because this will grow without bound.
data TxMeta = TxMeta {
      -- | Transaction ID
      _txMetaId         :: Core.TxId

      -- | Total amount
      --
      -- TODO: What does this mean?
    , _txMetaAmount     :: Core.Coin

      -- | Transaction inputs
    , _txMetaInputs     :: NonEmpty (Core.Address, Core.Coin)

      -- | Transaction outputs
    , _txMetaOutputs    :: NonEmpty (Core.Address, Core.Coin)

      -- | Transaction creation time
    , _txMetaCreationAt :: Core.Timestamp

      -- | Is this a local transaction?
      --
      -- A transaction is local when /all/ of its inputs and outputs are
      -- to and from addresses owned by this wallet.
    , _txMetaIsLocal    :: Bool

      -- | Is this an outgoing transaction?
      --
      -- A transaction is outgoing when it decreases the wallet's balance.
    , _txMetaIsOutgoing :: Bool
    } deriving Eq

makeLenses ''TxMeta

data InvariantViolation =
      DuplicatedTransaction Core.TxId
      -- ^ When attempting to insert a new 'MetaTx', the 'Core.TxId'
      -- identifying this transaction was already present in the storage.
      deriving Show

-- | A domain-specific collection of things which might go wrong when
-- storing & retrieving 'TxMeta' from a persistent storage.
data TxMetaStorageError =
      InvariantViolated InvariantViolation
    -- ^ One of the invariant was violated.
    | StorageFailure SomeException
    -- ^ The underlying storage failed to fulfill the request.
    deriving Show

instance Exception TxMetaStorageError

instance Buildable TxMetaStorageError where
    build storageErr = bprint shown storageErr

instance Arbitrary TxMeta where
    arbitrary = TxMeta <$> arbitrary
                       <*> arbitrary
                       <*> uniqueElements
                       <*> uniqueElements
                       <*> arbitrary
                       <*> arbitrary
                       <*> arbitrary

-- | Generates 'NonEmpty' collections which do not contain duplicates.
uniqueElements :: Gen (NonEmpty (Core.Address, Core.Coin))
uniqueElements = do
    (e :| es) <- arbitrary
    return (e :| (List.filter (/= e) (List.nub es)))

-- TODO(adinapoli): Proper 'Buildable' instance.
instance Buildable TxMeta where
    build txMeta = bprint ("TxMeta: id = "%shortHashF) (txMeta ^. txMetaId)
