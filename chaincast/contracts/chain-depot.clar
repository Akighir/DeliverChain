;; Define constants
(define-constant ERR-PERMISSION-DENIED (err u100))
(define-constant ERR-PACKAGE-ALREADY-IN-TRANSIT (err u101))
(define-constant ERR-BALANCE-TOO-LOW (err u102))
(define-constant ERR-PACKAGE-UNAVAILABLE (err u103))
(define-constant ERR-PACKAGE-ID-INVALID (err u108))

;; Define data maps
(define-map package-registry 
  { package-id: uint }
  {
    owner: principal,
    delivery-agent: (optional principal),
    package-size: uint,
    delivery-address: (string-ascii 30),
    package-description: (string-ascii 20),
    delivery-status: (string-ascii 20)
  }
)

(define-map token-balances principal uint)

;; Define functions
(define-public (create-package (package-size uint) (delivery-address (string-ascii 30)) 
                               (package-description (string-ascii 20)))
  (let ((package-id (+ (var-get package-counter) u1)))
    ;; Validate input parameters
    (asserts! (> package-size u0) (err u105))
    
    (map-set package-registry 
      { package-id: package-id }
      {
        owner: tx-sender,
        delivery-agent: none,
        package-size: package-size,
        delivery-address: delivery-address,
        package-description: package-description,
        delivery-status: "READY"
      }
    )
    
    (var-set package-counter package-id)
    (ok package-id)
  )
)

(define-public (accept-delivery (package-id uint))
  (let (
    (package-data (unwrap! (map-get? package-registry { package-id: package-id }) ERR-PACKAGE-UNAVAILABLE))
    (agent-balance (default-to u0 (map-get? token-balances tx-sender)))
  )
    ;; Validate package ID and status
    (asserts! (<= package-id (var-get package-counter)) ERR-PACKAGE-ID-INVALID)
    (asserts! (is-none (get delivery-agent package-data)) ERR-PACKAGE-ALREADY-IN-TRANSIT)
    (asserts! (is-eq (get delivery-status package-data) "READY") ERR-PACKAGE-UNAVAILABLE)
    (asserts! (>= agent-balance (get package-size package-data)) ERR-BALANCE-TOO-LOW)
    
    (map-set package-registry { package-id: package-id }
      (merge package-data { 
        delivery-agent: (some tx-sender),
        delivery-status: "TRANSIT"
      })
    )
    (map-set token-balances tx-sender (- agent-balance (get package-size package-data)))
    (map-set token-balances (get owner package-data) (+ (default-to u0 (map-get? token-balances (get owner package-data))) (get package-size package-data)))
    (ok true)
  )
)

(define-public (confirm-receipt (package-id uint))
  (let (
    (package-data (unwrap! (map-get? package-registry { package-id: package-id }) ERR-PACKAGE-UNAVAILABLE))
  )
    ;; Validate package ID and conditions
    (asserts! (<= package-id (var-get package-counter)) ERR-PACKAGE-ID-INVALID)
    (asserts! (is-eq (get owner package-data) tx-sender) ERR-PERMISSION-DENIED)
    (asserts! (is-eq (get delivery-status package-data) "TRANSIT") ERR-PACKAGE-UNAVAILABLE)
    
    ;; Mark package as delivered
    (map-set package-registry { package-id: package-id } (merge package-data { delivery-status: "COMPLETED" }))
    (ok true)
  )
)

(define-public (add-tokens (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances tx-sender)))
  )
    (map-set token-balances tx-sender (+ current-balance amount))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-package-details (package-id uint))
  (map-get? package-registry { package-id: package-id })
)

(define-read-only (check-balance (user principal))
  (default-to u0 (map-get? token-balances user))
)

;; Initialize counters and data
(define-data-var package-counter uint u0)