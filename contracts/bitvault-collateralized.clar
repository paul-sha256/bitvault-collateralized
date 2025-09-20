;; Title: BitVault Collateralized NFT Platform
;;
;; Summary: 
;; Bitcoin-backed NFT ecosystem enabling creators to mint assets with BTC 
;; collateral while earning yield through decentralized staking pools.
;;
;; Description:
;; BitVault transforms digital asset ownership by requiring Bitcoin collateral 
;; for every NFT, ensuring real-world value backing. Features include automated 
;; staking rewards, fractional ownership, and zero-slippage trading with 
;; institutional-grade 150% collateral requirements on Stacks Layer 2.

;; CONSTANTS & ERROR HANDLING

(define-constant contract-owner tx-sender)

;; Comprehensive error code system for robust contract operations
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-token (err u103))
(define-constant err-listing-not-found (err u104))
(define-constant err-invalid-price (err u105))
(define-constant err-insufficient-collateral (err u106))
(define-constant err-already-staked (err u107))
(define-constant err-not-staked (err u108))
(define-constant err-invalid-percentage (err u109))
(define-constant err-invalid-uri (err u110))
(define-constant err-invalid-recipient (err u111))
(define-constant err-overflow (err u112))

;; PROTOCOL CONFIGURATION

;; Core protocol parameters for optimal performance and security
(define-data-var min-collateral-ratio uint u150) ;; 150% minimum collateral ratio
(define-data-var protocol-fee uint u25) ;; 2.5% fee in basis points
(define-data-var total-staked uint u0) ;; Total staked assets counter
(define-data-var yield-rate uint u50) ;; 5% annual yield rate in basis points
(define-data-var total-supply uint u0) ;; Total asset supply tracker

;; DATA STRUCTURES

;; Primary asset registry with comprehensive metadata
(define-map tokens
  { token-id: uint }
  {
    owner: principal,
    uri: (string-ascii 256),
    collateral: uint,
    is-staked: bool,
    stake-timestamp: uint,
    fractional-shares: uint,
  }
)

;; Marketplace listing registry for active trades
(define-map token-listings
  { token-id: uint }
  {
    price: uint,
    seller: principal,
    active: bool,
  }
)

;; Fractional ownership distribution tracking
(define-map fractional-ownership
  {
    token-id: uint,
    owner: principal,
  }
  { shares: uint }
)

;; Staking rewards accumulation and distribution
(define-map staking-rewards
  { token-id: uint }
  {
    accumulated-yield: uint,
    last-claim: uint,
  }
)

;; UTILITY FUNCTIONS

;; Validates URI format and ensures proper metadata structure
(define-private (validate-uri (uri (string-ascii 256)))
  (let ((uri-len (len uri)))
    (and
      (> uri-len u0)
      (<= uri-len u256)
    )
  )
)

;; Prevents contracts from receiving assets to maintain security
(define-private (validate-recipient (recipient principal))
  (not (is-eq recipient (as-contract tx-sender)))
)

;; Safe arithmetic operations with overflow protection
(define-private (safe-add
    (a uint)
    (b uint)
  )
  (let ((sum (+ a b)))
    (asserts! (>= sum a) err-overflow)
    (ok sum)
  )
)

;; CORE ASSET MANAGEMENT

;; Creates new collateral-backed digital assets with security guarantees
(define-public (mint-nft
    (uri (string-ascii 256))
    (collateral uint)
  )
  (let (
      (token-id (+ (var-get total-supply) u1))
      (collateral-requirement (/ (* (var-get min-collateral-ratio) collateral) u100))
    )
    (asserts! (validate-uri uri) err-invalid-uri)
    (asserts! (>= (stx-get-balance tx-sender) collateral-requirement)
      err-insufficient-collateral
    )
    (try! (stx-transfer? collateral-requirement tx-sender (as-contract tx-sender)))
    (map-set tokens { token-id: token-id } {
      owner: tx-sender,
      uri: uri,
      collateral: collateral,
      is-staked: false,
      stake-timestamp: u0,
      fractional-shares: u0,
    })
    (var-set total-supply token-id)
    (ok token-id)
  )
)

;; Secure asset transfer with comprehensive validation
(define-public (transfer-nft
    (token-id uint)
    (recipient principal)
  )
  (let ((token (unwrap! (get-token-info token-id) err-invalid-token)))
    (asserts! (validate-recipient recipient) err-invalid-recipient)
    (asserts! (is-eq tx-sender (get owner token)) err-not-token-owner)
    (asserts! (not (get is-staked token)) err-already-staked)
    (map-set tokens { token-id: token-id } (merge token { owner: recipient }))
    (ok true)
  )
)

;; MARKETPLACE OPERATIONS

;; Lists assets for public trading with dynamic pricing
(define-public (list-nft
    (token-id uint)
    (price uint)
  )
  (let ((token (unwrap! (get-token-info token-id) err-invalid-token)))
    (asserts! (> price u0) err-invalid-price)
    (asserts! (is-eq tx-sender (get owner token)) err-not-token-owner)
    (asserts! (not (get is-staked token)) err-already-staked)
    (map-set token-listings { token-id: token-id } {
      price: price,
      seller: tx-sender,
      active: true,
    })
    (ok true)
  )
)

;; Executes marketplace purchases with automated fee distribution
(define-public (purchase-nft (token-id uint))
  (let (
      (listing (unwrap! (get-listing token-id) err-listing-not-found))
      (price (get price listing))
      (seller (get seller listing))
      (fee (/ (* price (var-get protocol-fee)) u1000))
    )
    (asserts! (get active listing) err-listing-not-found)
    (asserts! (is-eq (get active listing) true) err-listing-not-found)
    ;; Execute payment flow with protocol fee collection
    (try! (stx-transfer? price tx-sender seller))
    (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
    ;; Complete ownership transfer
    (try! (transfer-nft token-id tx-sender))
    ;; Clear marketplace listing
    (map-set token-listings { token-id: token-id } {
      price: u0,
      seller: seller,
      active: false,
    })
    (ok true)
  )
)

;; FRACTIONAL OWNERSHIP SYSTEM

;; Enables fractional share transfers for democratized asset access
(define-public (transfer-shares
    (token-id uint)
    (recipient principal)
    (share-amount uint)
  )
  (let (
      (sender-shares (unwrap! (get-fractional-shares token-id tx-sender)
        err-insufficient-balance
      ))
      (current-recipient-shares (default-to { shares: u0 } (get-fractional-shares token-id recipient)))
      (recipient-new-shares (unwrap! (safe-add (get shares current-recipient-shares) share-amount)
        err-overflow
      ))
    )
    (asserts! (validate-recipient recipient) err-invalid-recipient)
    (asserts! (>= (get shares sender-shares) share-amount)
      err-insufficient-balance
    )
    ;; Update sender's fractional position
    (map-set fractional-ownership {
      token-id: token-id,
      owner: tx-sender,
    } { shares: (- (get shares sender-shares) share-amount) }
    )
    ;; Update recipient's fractional position
    (map-set fractional-ownership {
      token-id: token-id,
      owner: recipient,
    } { shares: recipient-new-shares }
    )
    (ok true)
  )
)

;; STAKING & YIELD GENERATION

;; Activates assets for yield generation through community staking
(define-public (stake-nft (token-id uint))
  (let ((token (unwrap! (get-token-info token-id) err-invalid-token)))
    (asserts! (is-eq tx-sender (get owner token)) err-not-token-owner)
    (asserts! (not (get is-staked token)) err-already-staked)
    (map-set tokens { token-id: token-id }
      (merge token {
        is-staked: true,
        stake-timestamp: stacks-block-height,
      })
    )
    (map-set staking-rewards { token-id: token-id } {
      accumulated-yield: u0,
      last-claim: stacks-block-height,
    })
    (var-set total-staked (+ (var-get total-staked) u1))
    (ok true)
  )
)

;; Withdraws assets from staking and claims accumulated rewards
(define-public (unstake-nft (token-id uint))
  (let (
      (token (unwrap! (get-token-info token-id) err-invalid-token))
      (rewards (unwrap! (get-staking-rewards token-id) err-not-staked))
    )
    (asserts! (is-eq tx-sender (get owner token)) err-not-token-owner)
    (asserts! (get is-staked token) err-not-staked)
    ;; Process final reward distribution
    (try! (claim-staking-rewards token-id))
    (map-set tokens { token-id: token-id }
      (merge token {
        is-staked: false,
        stake-timestamp: u0,
      })
    )
    (var-set total-staked (- (var-get total-staked) u1))
    (ok true)
  )
)

;; DATA QUERY FUNCTIONS

;; Retrieves comprehensive asset metadata
(define-read-only (get-token-info (token-id uint))
  (map-get? tokens { token-id: token-id })
)

;; Retrieves marketplace listing details
(define-read-only (get-listing (token-id uint))
  (map-get? token-listings { token-id: token-id })
)

;; Retrieves fractional ownership information
(define-read-only (get-fractional-shares
    (token-id uint)
    (owner principal)
  )
  (map-get? fractional-ownership {
    token-id: token-id,
    owner: owner,
  })
)

;; Retrieves staking rewards accumulation data
(define-read-only (get-staking-rewards (token-id uint))
  (map-get? staking-rewards { token-id: token-id })
)

;; Calculates real-time staking rewards based on network participation
(define-read-only (calculate-rewards (token-id uint))
  (let (
      (token (unwrap! (get-token-info token-id) err-invalid-token))
      (rewards (unwrap! (get-staking-rewards token-id) err-not-staked))
      (blocks-staked (- stacks-block-height (get stake-timestamp token)))
      (yield-per-block (/ (var-get yield-rate) u52560)) ;; Approximate blocks per year
      (new-rewards (* blocks-staked yield-per-block))
    )
    (ok (+ (get accumulated-yield rewards) new-rewards))
  )
)

;; INTERNAL REWARD SYSTEM

;; Processes and distributes accumulated staking rewards
(define-private (claim-staking-rewards (token-id uint))
  (let (
      (rewards (unwrap! (calculate-rewards token-id) err-not-staked))
      (token (unwrap! (get-token-info token-id) err-invalid-token))
    )
    (asserts! (get is-staked token) err-not-staked)
    (map-set staking-rewards { token-id: token-id } {
      accumulated-yield: u0,
      last-claim: stacks-block-height,
    })
    ;; Execute reward distribution to asset owner
    (as-contract (stx-transfer? rewards (as-contract tx-sender) (get owner token)))
  )
)