# BitVault Collateralized NFT Platform

## Overview

**BitVault** is a Bitcoin-backed NFT protocol built on **Stacks Layer 2**. The platform enables creators and investors to mint NFTs with **Bitcoin collateral**, ensuring intrinsic value, yield opportunities, and institutional-grade security.

Core features:

* **Collateralized NFTs** – Every asset requires BTC-backed collateral with a **150% minimum ratio**.
* **Fractional Ownership** – Democratized access through share-based ownership transfers.
* **Marketplace Integration** – Seamless, zero-slippage NFT trading with protocol-level fee distribution.
* **Staking & Yield** – Assets can be staked to earn yield from decentralized pools, with automated reward distribution.
* **Institutional Security** – Transparent error handling, overflow protection, and enforced collateralization guarantees.

---

## System Architecture

At a high level, BitVault consists of **four integrated modules**:

1. **NFT Core Module**

   * Collateralized asset minting
   * Secure transfer and ownership management
   * URI validation and on-chain metadata tracking

2. **Marketplace Module**

   * Listing, pricing, and trade execution
   * Automated protocol fee collection
   * Secure ownership transfer flow

3. **Fractionalization Module**

   * Ownership share distribution
   * Share transfers with overflow and balance validation
   * Democratized asset access without losing collateral guarantees

4. **Staking & Rewards Module**

   * NFT staking activation with block-based yield accrual
   * Real-time reward calculation per block height
   * Reward claiming and automated STX distribution

---

## Contract Architecture

### Key Data Structures

* **`tokens`**
  Registry of NFTs, including metadata, collateral amount, staking state, and fractional shares.

* **`token-listings`**
  Active marketplace listings with price, seller, and status flags.

* **`fractional-ownership`**
  Mapping of token ID + owner → fractional share balance.

* **`staking-rewards`**
  Per-token staking yield accumulation with last-claim tracking.

### Core Constants & Parameters

* **`min-collateral-ratio`** → Default `u150` (150%)
* **`protocol-fee`** → Default `u25` (2.5%)
* **`yield-rate`** → Default `u50` (5% annualized, block-based accrual)

### Security & Error Handling

* Comprehensive error codes (`u100–u112`) for robust failure reporting.
* Safe arithmetic utilities (`safe-add`) with overflow checks.
* Strict ownership and collateral enforcement to prevent unauthorized transfers.

---

## Data Flow

### Minting Flow

1. User submits URI + collateral.
2. Contract validates URI and collateral ratio.
3. Required STX collateral is locked into the contract.
4. New NFT is registered in `tokens` map and `total-supply` updated.

### Marketplace Flow

1. NFT owner lists asset with price.
2. Buyer executes `purchase-nft`.
3. Protocol fee is extracted; seller receives proceeds.
4. Ownership is securely transferred; listing is cleared.

### Staking Flow

1. NFT owner calls `stake-nft`.
2. Rewards accrue per block based on `yield-rate`.
3. Owner calls `unstake-nft` to exit; rewards are automatically claimed and distributed.

---

## Contract Functions

### Public Entry Points

* `mint-nft` – Mint collateralized NFTs
* `transfer-nft` – Secure NFT transfer
* `list-nft` / `purchase-nft` – Marketplace operations
* `transfer-shares` – Fractional ownership transfers
* `stake-nft` / `unstake-nft` – Yield staking lifecycle

### Read-Only Queries

* `get-token-info` – Retrieve NFT metadata
* `get-listing` – Get marketplace listing details
* `get-fractional-shares` – Query share balances
* `get-staking-rewards` – Fetch staking reward state
* `calculate-rewards` – Real-time yield calculation

---

## Security Considerations

* **Collateral Enforcement** – NFTs cannot be minted without 150% BTC collateral locked.
* **Ownership Validation** – Only token owners can list, transfer, stake, or fractionalize assets.
* **Overflow Protection** – Arithmetic guarded with assertions.
* **Non-Contract Recipients** – Prevents contract recipients to mitigate attack vectors.
* **Staking Guarantees** – Yield claims require staking validation, ensuring reward integrity.

---

## Future Extensions

* Multi-asset collateral support (beyond BTC/STX).
* DAO-driven governance for yield-rate adjustments.
* Layered staking pools with dynamic APY.
* Advanced fractionalization (ERC-1155 equivalent).
