;; Entity Verification Contract
;; Validates and certifies regenerative businesses within the supply chain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-status (err u104))

;; Data Variables
(define-data-var next-business-id uint u1)
(define-data-var verification-fee uint u1000000) ;; 1 STX in microSTX

;; Data Maps
(define-map businesses
  { business-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    owner: principal,
    registration-block: uint,
    status: (string-ascii 20),
    verification-score: uint,
    criteria-met: (list 10 (string-ascii 50))
  }
)

(define-map business-verifications
  { business-id: uint, verifier: principal }
  {
    verified-at: uint,
    verification-type: (string-ascii 50),
    score: uint,
    notes: (string-ascii 200)
  }
)

(define-map authorized-verifiers
  { verifier: principal }
  {
    authorized: bool,
    specialization: (string-ascii 100),
    authorized-at: uint
  }
)

(define-map regenerative-criteria
  { criteria-id: (string-ascii 50) }
  {
    description: (string-ascii 200),
    weight: uint,
    active: bool
  }
)

;; Read-only functions

(define-read-only (get-business (business-id uint))
  (map-get? businesses { business-id: business-id })
)

(define-read-only (get-business-verification (business-id uint) (verifier principal))
  (map-get? business-verifications { business-id: business-id, verifier: verifier })
)

(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (get authorized (map-get? authorized-verifiers { verifier: verifier })))
)

(define-read-only (get-criteria (criteria-id (string-ascii 50)))
  (map-get? regenerative-criteria { criteria-id: criteria-id })
)

(define-read-only (get-next-business-id)
  (var-get next-business-id)
)

(define-read-only (get-verification-fee)
  (var-get verification-fee)
)

;; Public functions

(define-public (register-business
  (name (string-ascii 100))
  (description (string-ascii 500))
  (criteria (list 10 (string-ascii 50))))
  (let
    (
      (business-id (var-get next-business-id))
    )
    (asserts! (> (len name) u0) (err u105))
    (asserts! (is-none (map-get? businesses { business-id: business-id })) err-already-exists)

    (map-set businesses
      { business-id: business-id }
      {
        name: name,
        description: description,
        owner: tx-sender,
        registration-block: block-height,
        status: "pending",
        verification-score: u0,
        criteria-met: criteria
      }
    )

    (var-set next-business-id (+ business-id u1))
    (ok business-id)
  )
)

(define-public (verify-business
  (business-id uint)
  (verification-type (string-ascii 50))
  (score uint)
  (notes (string-ascii 200)))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) err-not-found))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) err-unauthorized))
    )
    (asserts! (get authorized verifier-info) err-unauthorized)
    (asserts! (<= score u100) (err u106))

    ;; Record the verification
    (map-set business-verifications
      { business-id: business-id, verifier: tx-sender }
      {
        verified-at: block-height,
        verification-type: verification-type,
        score: score,
        notes: notes
      }
    )

    ;; Update business status and score
    (map-set businesses
      { business-id: business-id }
      (merge business {
        status: (if (>= score u70) "verified" "rejected"),
        verification-score: score
      })
    )

    (ok true)
  )
)

(define-public (authorize-verifier
  (verifier principal)
  (specialization (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    (map-set authorized-verifiers
      { verifier: verifier }
      {
        authorized: true,
        specialization: specialization,
        authorized-at: block-height
      }
    )

    (ok true)
  )
)

(define-public (revoke-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    (map-set authorized-verifiers
      { verifier: verifier }
      {
        authorized: false,
        specialization: "",
        authorized-at: block-height
      }
    )

    (ok true)
  )
)

(define-public (add-regenerative-criteria
  (criteria-id (string-ascii 50))
  (description (string-ascii 200))
  (weight uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? regenerative-criteria { criteria-id: criteria-id })) err-already-exists)

    (map-set regenerative-criteria
      { criteria-id: criteria-id }
      {
        description: description,
        weight: weight,
        active: true
      }
    )

    (ok true)
  )
)

(define-public (update-business-status
  (business-id uint)
  (new-status (string-ascii 20)))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) err-not-found))
    )
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get owner business))) err-unauthorized)

    (map-set businesses
      { business-id: business-id }
      (merge business { status: new-status })
    )

    (ok true)
  )
)

(define-public (update-verification-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set verification-fee new-fee)
    (ok true)
  )
)

(define-public (pay-verification-fee (business-id uint))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) err-not-found))
      (fee (var-get verification-fee))
    )
    (asserts! (is-eq tx-sender (get owner business)) err-unauthorized)

    (try! (stx-transfer? fee tx-sender contract-owner))

    (ok true)
  )
)

;; Initialize default criteria
(map-set regenerative-criteria
  { criteria-id: "carbon-negative" }
  {
    description: "Business operations result in net carbon removal",
    weight: u25,
    active: true
  }
)

(map-set regenerative-criteria
  { criteria-id: "biodiversity-positive" }
  {
    description: "Activities increase local biodiversity",
    weight: u20,
    active: true
  }
)

(map-set regenerative-criteria
  { criteria-id: "soil-health" }
  {
    description: "Practices improve soil health and fertility",
    weight: u20,
    active: true
  }
)

(map-set regenerative-criteria
  { criteria-id: "water-stewardship" }
  {
    description: "Responsible water use and watershed protection",
    weight: u15,
    active: true
  }
)

(map-set regenerative-criteria
  { criteria-id: "community-benefit" }
  {
    description: "Positive impact on local communities",
    weight: u20,
    active: true
  }
)
