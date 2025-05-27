;; Entity Verification Contract
;; Validates regenerative businesses and their credentials

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ENTITY_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))

;; Entity data structure
(define-map entities
  { entity-id: uint }
  {
    name: (string-ascii 100),
    owner: principal,
    verified: bool,
    verification-date: uint,
    regenerative-score: uint
  }
)

;; Entity counter
(define-data-var entity-counter uint u0)

;; Register a new entity
(define-public (register-entity (name (string-ascii 100)))
  (let ((entity-id (+ (var-get entity-counter) u1)))
    (map-set entities
      { entity-id: entity-id }
      {
        name: name,
        owner: tx-sender,
        verified: false,
        verification-date: u0,
        regenerative-score: u0
      }
    )
    (var-set entity-counter entity-id)
    (ok entity-id)
  )
)

;; Verify an entity (only contract owner)
(define-public (verify-entity (entity-id uint) (score uint))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (match (map-get? entities { entity-id: entity-id })
      entity-data
      (if (get verified entity-data)
        ERR_ALREADY_VERIFIED
        (begin
          (map-set entities
            { entity-id: entity-id }
            (merge entity-data {
              verified: true,
              verification-date: block-height,
              regenerative-score: score
            })
          )
          (ok true)
        )
      )
      ERR_ENTITY_NOT_FOUND
    )
    ERR_UNAUTHORIZED
  )
)

;; Get entity information
(define-read-only (get-entity (entity-id uint))
  (map-get? entities { entity-id: entity-id })
)

;; Check if entity is verified
(define-read-only (is-verified (entity-id uint))
  (match (map-get? entities { entity-id: entity-id })
    entity-data (get verified entity-data)
    false
  )
)
