(define-non-fungible-token farm-plot uint)
(define-fungible-token rotation-reward)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PLOT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-ROTATION (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-TOO-EARLY (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-ORACLE-NOT-AUTHORIZED (err u106))
(define-constant ERR-INVALID-CROP-TYPE (err u107))
(define-constant ERR-POOL-NOT-FOUND (err u108))
(define-constant ERR-ALREADY-IN-POOL (err u109))
(define-constant ERR-NOT-IN-POOL (err u110))
(define-constant ERR-POOL-FULL (err u111))
(define-constant ERR-INSUFFICIENT-MEMBERS (err u112))
(define-constant ERR-LISTING-NOT-FOUND (err u113))
(define-constant ERR-LISTING-INACTIVE (err u114))
(define-constant ERR-INVALID-AMOUNT (err u115))
(define-constant ERR-ESCROW-NOT-FOUND (err u116))
(define-constant ERR-INVALID-BUYER (err u117))

(define-constant ROTATION-CYCLE-BLOCKS u1008)
(define-constant MIN-COMPLIANCE-PERIOD u144)
(define-constant REWARD-MULTIPLIER u100)
(define-constant BASE-REWARD u1000)
(define-constant POOL-BONUS-MULTIPLIER u150)
(define-constant MAX-POOL-MEMBERS u10)
(define-constant MIN-POOL-MEMBERS u2)
(define-constant ESCROW-TIMEOUT-BLOCKS u288)

(define-data-var plot-counter uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var contract-paused bool false)
(define-data-var pool-counter uint u0)
(define-data-var listing-counter uint u0)

(define-map plots
  uint
  {
    owner: principal,
    size: uint,
    location: (string-ascii 50),
    current-crop: uint,
    last-rotation: uint,
    compliance-streak: uint,
    total-rewards-earned: uint
  }
)

(define-map crop-types
  uint
  {
    name: (string-ascii 20),
    category: uint,
    season-length: uint
  }
)

(define-map rotation-rules
  { from-crop: uint, to-crop: uint }
  { allowed: bool, bonus-multiplier: uint }
)

(define-map authorized-oracles
  principal
  { active: bool, verification-count: uint }
)

(define-map farmer-stats
  principal
  {
    total-plots: uint,
    total-rewards: uint,
    compliance-score: uint
  }
)

(define-map crop-history
  { plot-id: uint, block-height: uint }
  { crop-type: uint, verified: bool }
)

(define-map farming-pools
  uint
  {
    name: (string-ascii 30),
    creator: principal,
    member-count: uint,
    total-pooled-size: uint,
    created-at: uint,
    active: bool
  }
)

(define-map pool-members
  { pool-id: uint, member: principal }
  { joined-at: uint, plots-contributed: uint }
)

(define-map plot-pool-assignment
  uint
  { pool-id: uint }
)

(define-map crop-listings
  uint
  {
    seller: principal,
    crop-type: uint,
    quantity: uint,
    price-per-unit: uint,
    plot-id: uint,
    listed-at: uint,
    active: bool,
    requires-compliance: bool
  }
)

(define-map escrow-orders
  uint
  {
    listing-id: uint,
    buyer: principal,
    amount: uint,
    quantity: uint,
    created-at: uint,
    completed: bool
  }
)

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-oracle (oracle principal))
  (default-to false (get active (map-get? authorized-oracles oracle)))
)

(define-private (get-plot-owner (plot-id uint))
  (get owner (map-get? plots plot-id))
)

(define-private (is-plot-owner (plot-id uint) (user principal))
  (is-eq (some user) (get-plot-owner plot-id))
)

(define-private (calculate-reward (plot-size uint) (streak uint))
  (let (
    (base (* BASE-REWARD plot-size))
    (streak-bonus (* base (/ streak u10)))
  )
    (+ base streak-bonus)
  )
)

(define-private (is-valid-rotation (from-crop uint) (to-crop uint))
  (default-to false
    (get allowed (map-get? rotation-rules { from-crop: from-crop, to-crop: to-crop }))
  )
)

(define-private (update-farmer-stats (farmer principal) (reward uint))
  (let (
    (current-stats (default-to
      { total-plots: u0, total-rewards: u0, compliance-score: u0 }
      (map-get? farmer-stats farmer)
    ))
  )
    (map-set farmer-stats farmer
      (merge current-stats
        {
          total-rewards: (+ (get total-rewards current-stats) reward),
          compliance-score: (+ (get compliance-score current-stats) u1)
        }
      )
    )
  )
)

(define-private (is-plot-compliant (plot-id uint))
  (match (map-get? plots plot-id)
    plot-data (>= (get compliance-streak plot-data) u1)
    false
  )
)

(define-public (initialize-contract)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (try! (ft-mint? rotation-reward u1000000 tx-sender))
    (map-set crop-types u1 { name: "legumes", category: u1, season-length: u144 })
    (map-set crop-types u2 { name: "cereals", category: u2, season-length: u288 })
    (map-set crop-types u3 { name: "tubers", category: u3, season-length: u216 })
    (map-set crop-types u4 { name: "vegetables", category: u4, season-length: u144 })
    (map-set rotation-rules { from-crop: u1, to-crop: u2 } { allowed: true, bonus-multiplier: u120 })
    (map-set rotation-rules { from-crop: u2, to-crop: u3 } { allowed: true, bonus-multiplier: u110 })
    (map-set rotation-rules { from-crop: u3, to-crop: u4 } { allowed: true, bonus-multiplier: u115 })
    (map-set rotation-rules { from-crop: u4, to-crop: u1 } { allowed: true, bonus-multiplier: u125 })
    (map-set rotation-rules { from-crop: u1, to-crop: u3 } { allowed: true, bonus-multiplier: u105 })
    (map-set rotation-rules { from-crop: u2, to-crop: u4 } { allowed: true, bonus-multiplier: u105 })
    (ok true)
  )
)

(define-public (register-plot (size uint) (location (string-ascii 50)) (initial-crop uint))
  (let (
    (plot-id (+ (var-get plot-counter) u1))
    (current-height stacks-block-height)
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> size u0) ERR-INVALID-CROP-TYPE)
    (asserts! (is-some (map-get? crop-types initial-crop)) ERR-INVALID-CROP-TYPE)
    (try! (nft-mint? farm-plot plot-id tx-sender))
    (map-set plots plot-id
      {
        owner: tx-sender,
        size: size,
        location: location,
        current-crop: initial-crop,
        last-rotation: current-height,
        compliance-streak: u0,
        total-rewards-earned: u0
      }
    )
    (var-set plot-counter plot-id)
    (let (
      (current-farmer-stats (default-to
        { total-plots: u0, total-rewards: u0, compliance-score: u0 }
        (map-get? farmer-stats tx-sender)
      ))
    )
      (map-set farmer-stats tx-sender
        (merge current-farmer-stats
          { total-plots: (+ (get total-plots current-farmer-stats) u1) }
        )
      )
    )
    (map-set crop-history { plot-id: plot-id, block-height: current-height }
      { crop-type: initial-crop, verified: false }
    )
    (ok plot-id)
  )
)

(define-public (rotate-crop (plot-id uint) (new-crop uint))
  (let (
    (plot-data (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (current-height stacks-block-height)
    (time-since-last (- current-height (get last-rotation plot-data)))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-plot-owner plot-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? crop-types new-crop)) ERR-INVALID-CROP-TYPE)
    (asserts! (>= time-since-last MIN-COMPLIANCE-PERIOD) ERR-TOO-EARLY)
    (asserts! (is-valid-rotation (get current-crop plot-data) new-crop) ERR-INVALID-ROTATION)
    (map-set plots plot-id
      (merge plot-data
        {
          current-crop: new-crop,
          last-rotation: current-height
        }
      )
    )
    (map-set crop-history { plot-id: plot-id, block-height: current-height }
      { crop-type: new-crop, verified: false }
    )
    (ok true)
  )
)

(define-public (verify-compliance (plot-id uint) (target-height uint))
  (let (
    (plot-data (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (history-key { plot-id: plot-id, block-height: target-height })
    (crop-record (unwrap! (map-get? crop-history history-key) ERR-PLOT-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-authorized-oracle tx-sender) ERR-ORACLE-NOT-AUTHORIZED)
    (asserts! (not (get verified crop-record)) ERR-ALREADY-EXISTS)
    (map-set crop-history history-key
      (merge crop-record { verified: true })
    )
    (let (
      (oracle-stats (default-to { active: true, verification-count: u0 }
        (map-get? authorized-oracles tx-sender)
      ))
    )
      (map-set authorized-oracles tx-sender
        (merge oracle-stats
          { verification-count: (+ (get verification-count oracle-stats) u1) }
        )
      )
    )
    (ok true)
  )
)

(define-public (claim-rewards (plot-id uint))
  (let (
    (plot-data (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (current-height stacks-block-height)
    (time-since-last (- current-height (get last-rotation plot-data)))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-plot-owner plot-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= time-since-last ROTATION-CYCLE-BLOCKS) ERR-TOO-EARLY)
    (let (
      (history-verified (default-to false
        (get verified (map-get? crop-history { plot-id: plot-id, block-height: (get last-rotation plot-data) }))
      ))
      (reward-amount (if history-verified
        (calculate-reward (get size plot-data) (+ (get compliance-streak plot-data) u1))
        u0
      ))
    )
      (if (> reward-amount u0)
        (begin
          (try! (ft-transfer? rotation-reward reward-amount CONTRACT-OWNER tx-sender))
          (map-set plots plot-id
            (merge plot-data
              {
                compliance-streak: (+ (get compliance-streak plot-data) u1),
                total-rewards-earned: (+ (get total-rewards-earned plot-data) reward-amount)
              }
            )
          )
          (update-farmer-stats tx-sender reward-amount)
          (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
          (ok reward-amount)
        )
        (ok u0)
      )
    )
  )
)

(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set authorized-oracles oracle { active: true, verification-count: u0 })
    (ok true)
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-delete authorized-oracles oracle)
    (ok true)
  )
)

(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

(define-read-only (get-plot-info (plot-id uint))
  (map-get? plots plot-id)
)

(define-read-only (get-crop-type (crop-id uint))
  (map-get? crop-types crop-id)
)

(define-read-only (get-rotation-rule (from-crop uint) (to-crop uint))
  (map-get? rotation-rules { from-crop: from-crop, to-crop: to-crop })
)

(define-read-only (get-farmer-stats (farmer principal))
  (map-get? farmer-stats farmer)
)

(define-read-only (get-crop-history (plot-id uint) (target-height uint))
  (map-get? crop-history { plot-id: plot-id, block-height: target-height })
)

(define-read-only (is-oracle-authorized (oracle principal))
  (is-authorized-oracle oracle)
)

(define-read-only (get-contract-stats)
  {
    total-plots: (var-get plot-counter),
    total-rewards-distributed: (var-get total-rewards-distributed),
    contract-paused: (var-get contract-paused)
  }
)

(define-read-only (calculate-potential-reward (plot-id uint))
  (match (map-get? plots plot-id)
    plot-data (ok (calculate-reward (get size plot-data) (get compliance-streak plot-data)))
    ERR-PLOT-NOT-FOUND
  )
)

(define-public (create-farming-pool (pool-name (string-ascii 30)))
  (let (
    (pool-id (+ (var-get pool-counter) u1))
    (current-height stacks-block-height)
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (map-set farming-pools pool-id
      {
        name: pool-name,
        creator: tx-sender,
        member-count: u0,
        total-pooled-size: u0,
        created-at: current-height,
        active: true
      }
    )
    (var-set pool-counter pool-id)
    (ok pool-id)
  )
)

(define-public (join-pool (pool-id uint) (plot-id uint))
  (let (
    (pool-data (unwrap! (map-get? farming-pools pool-id) ERR-POOL-NOT-FOUND))
    (plot-data (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (current-height stacks-block-height)
    (member-key { pool-id: pool-id, member: tx-sender })
    (existing-assignment (map-get? plot-pool-assignment plot-id))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-plot-owner plot-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get active pool-data) ERR-POOL-NOT-FOUND)
    (asserts! (is-none existing-assignment) ERR-ALREADY-IN-POOL)
    (asserts! (< (get member-count pool-data) MAX-POOL-MEMBERS) ERR-POOL-FULL)
    (let (
      (existing-member (map-get? pool-members member-key))
      (plots-contributed (if (is-some existing-member)
        (get plots-contributed (unwrap-panic existing-member))
        u0
      ))
    )
      (map-set plot-pool-assignment plot-id { pool-id: pool-id })
      (map-set pool-members member-key
        {
          joined-at: current-height,
          plots-contributed: (+ plots-contributed u1)
        }
      )
      (map-set farming-pools pool-id
        (merge pool-data
          {
            member-count: (if (is-none existing-member)
              (+ (get member-count pool-data) u1)
              (get member-count pool-data)
            ),
            total-pooled-size: (+ (get total-pooled-size pool-data) (get size plot-data))
          }
        )
      )
      (ok true)
    )
  )
)

(define-public (leave-pool (plot-id uint))
  (let (
    (plot-data (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (assignment (unwrap! (map-get? plot-pool-assignment plot-id) ERR-NOT-IN-POOL))
    (pool-id (get pool-id assignment))
    (pool-data (unwrap! (map-get? farming-pools pool-id) ERR-POOL-NOT-FOUND))
    (member-key { pool-id: pool-id, member: tx-sender })
    (member-data (unwrap! (map-get? pool-members member-key) ERR-NOT-IN-POOL))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-plot-owner plot-id tx-sender) ERR-NOT-AUTHORIZED)
    (map-delete plot-pool-assignment plot-id)
    (let (
      (new-plots-contributed (- (get plots-contributed member-data) u1))
    )
      (if (is-eq new-plots-contributed u0)
        (begin
          (map-delete pool-members member-key)
          (map-set farming-pools pool-id
            (merge pool-data
              {
                member-count: (- (get member-count pool-data) u1),
                total-pooled-size: (- (get total-pooled-size pool-data) (get size plot-data))
              }
            )
          )
        )
        (begin
          (map-set pool-members member-key
            (merge member-data { plots-contributed: new-plots-contributed })
          )
          (map-set farming-pools pool-id
            (merge pool-data
              { total-pooled-size: (- (get total-pooled-size pool-data) (get size plot-data)) }
            )
          )
        )
      )
      (ok true)
    )
  )
)

(define-public (claim-pool-rewards (plot-id uint))
  (let (
    (plot-data (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (assignment (unwrap! (map-get? plot-pool-assignment plot-id) ERR-NOT-IN-POOL))
    (pool-id (get pool-id assignment))
    (pool-data (unwrap! (map-get? farming-pools pool-id) ERR-POOL-NOT-FOUND))
    (current-height stacks-block-height)
    (time-since-last (- current-height (get last-rotation plot-data)))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-plot-owner plot-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get active pool-data) ERR-POOL-NOT-FOUND)
    (asserts! (>= (get member-count pool-data) MIN-POOL-MEMBERS) ERR-INSUFFICIENT-MEMBERS)
    (asserts! (>= time-since-last ROTATION-CYCLE-BLOCKS) ERR-TOO-EARLY)
    (let (
      (history-verified (default-to false
        (get verified (map-get? crop-history { plot-id: plot-id, block-height: (get last-rotation plot-data) }))
      ))
      (base-reward (if history-verified
        (calculate-reward (get size plot-data) (+ (get compliance-streak plot-data) u1))
        u0
      ))
      (pool-bonus (/ (* base-reward POOL-BONUS-MULTIPLIER) u100))
      (total-reward (+ base-reward pool-bonus))
    )
      (if (> total-reward u0)
        (begin
          (try! (ft-transfer? rotation-reward total-reward CONTRACT-OWNER tx-sender))
          (map-set plots plot-id
            (merge plot-data
              {
                compliance-streak: (+ (get compliance-streak plot-data) u1),
                total-rewards-earned: (+ (get total-rewards-earned plot-data) total-reward)
              }
            )
          )
          (update-farmer-stats tx-sender total-reward)
          (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) total-reward))
          (ok total-reward)
        )
        (ok u0)
      )
    )
  )
)

(define-public (deactivate-pool (pool-id uint))
  (let (
    (pool-data (unwrap! (map-get? farming-pools pool-id) ERR-POOL-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get creator pool-data)) ERR-NOT-AUTHORIZED)
    (map-set farming-pools pool-id
      (merge pool-data { active: false })
    )
    (ok true)
  )
)

(define-read-only (get-pool-info (pool-id uint))
  (map-get? farming-pools pool-id)
)

(define-read-only (get-pool-member-info (pool-id uint) (member principal))
  (map-get? pool-members { pool-id: pool-id, member: member })
)

(define-read-only (get-plot-pool (plot-id uint))
  (map-get? plot-pool-assignment plot-id)
)

(define-read-only (is-plot-in-pool (plot-id uint))
  (is-some (map-get? plot-pool-assignment plot-id))
)

(define-public (list-crop-for-sale (plot-id uint) (quantity uint) (price-per-unit uint) (requires-compliance bool))
  (let (
    (plot-data (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (listing-id (+ (var-get listing-counter) u1))
    (current-height stacks-block-height)
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-plot-owner plot-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> quantity u0) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-unit u0) ERR-INVALID-AMOUNT)
    (if requires-compliance
      (asserts! (is-plot-compliant plot-id) ERR-NOT-AUTHORIZED)
      true
    )
    (map-set crop-listings listing-id
      {
        seller: tx-sender,
        crop-type: (get current-crop plot-data),
        quantity: quantity,
        price-per-unit: price-per-unit,
        plot-id: plot-id,
        listed-at: current-height,
        active: true,
        requires-compliance: requires-compliance
      }
    )
    (var-set listing-counter listing-id)
    (ok listing-id)
  )
)

(define-public (purchase-crop (listing-id uint) (quantity uint))
  (let (
    (listing (unwrap! (map-get? crop-listings listing-id) ERR-LISTING-NOT-FOUND))
    (total-cost (* (get price-per-unit listing) quantity))
    (current-height stacks-block-height)
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (get active listing) ERR-LISTING-INACTIVE)
    (asserts! (<= quantity (get quantity listing)) ERR-INVALID-AMOUNT)
    (asserts! (> quantity u0) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq tx-sender (get seller listing))) ERR-NOT-AUTHORIZED)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set escrow-orders listing-id
      {
        listing-id: listing-id,
        buyer: tx-sender,
        amount: total-cost,
        quantity: quantity,
        created-at: current-height,
        completed: false
      }
    )
    (let (
      (new-quantity (- (get quantity listing) quantity))
    )
      (map-set crop-listings listing-id
        (merge listing
          {
            quantity: new-quantity,
            active: (> new-quantity u0)
          }
        )
      )
    )
    (ok listing-id)
  )
)

(define-public (complete-order (listing-id uint))
  (let (
    (listing (unwrap! (map-get? crop-listings listing-id) ERR-LISTING-NOT-FOUND))
    (escrow (unwrap! (map-get? escrow-orders listing-id) ERR-ESCROW-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get completed escrow)) ERR-ALREADY-EXISTS)
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller listing))))
    (map-set escrow-orders listing-id
      (merge escrow { completed: true })
    )
    (ok true)
  )
)

(define-public (cancel-order (listing-id uint))
  (let (
    (listing (unwrap! (map-get? crop-listings listing-id) ERR-LISTING-NOT-FOUND))
    (escrow (unwrap! (map-get? escrow-orders listing-id) ERR-ESCROW-NOT-FOUND))
    (current-height stacks-block-height)
    (time-elapsed (- current-height (get created-at escrow)))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-INVALID-BUYER)
    (asserts! (not (get completed escrow)) ERR-ALREADY-EXISTS)
    (asserts! (>= time-elapsed ESCROW-TIMEOUT-BLOCKS) ERR-TOO-EARLY)
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
    (map-set crop-listings listing-id
      (merge listing
        {
          quantity: (+ (get quantity listing) (get quantity escrow)),
          active: true
        }
      )
    )
    (map-delete escrow-orders listing-id)
    (ok true)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let (
    (listing (unwrap! (map-get? crop-listings listing-id) ERR-LISTING-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
    (asserts! (get active listing) ERR-LISTING-INACTIVE)
    (map-set crop-listings listing-id
      (merge listing { active: false })
    )
    (ok true)
  )
)

(define-read-only (get-listing (listing-id uint))
  (map-get? crop-listings listing-id)
)

(define-read-only (get-escrow-order (listing-id uint))
  (map-get? escrow-orders listing-id)
)

(define-read-only (get-marketplace-stats)
  {
    total-listings: (var-get listing-counter)
  }
)