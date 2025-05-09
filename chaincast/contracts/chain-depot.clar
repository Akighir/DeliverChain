; Completed logistics platform with priority levels and user history tracking

;; Define constants
(define-constant ERR-PERMISSION-DENIED (err u100))
(define-constant ERR-PACKAGE-ALREADY-IN-TRANSIT (err u101))
(define-constant ERR-BALANCE-TOO-LOW (err u102))
(define-constant ERR-PACKAGE-UNAVAILABLE (err u103))
(define-constant ERR-DELIVERY-IN-PROGRESS (err u104))
(define-constant ERR-PACKAGE-SIZE-INVALID (err u105))
(define-constant ERR-COVERAGE-RATE-INVALID (err u106))
(define-constant ERR-DELIVERY-TIME-INVALID (err u107))
(define-constant ERR-PACKAGE-ID-INVALID (err u108))
(define-constant ERR-URGENCY-LEVEL-INVALID (err u109))
(define-constant ERR-PACKAGE-TERMINATED (err u110))

;; Define data maps
(define-map package-registry 
  { package-id: uint }
  {
    owner: principal,
    delivery-agent: (optional principal),
    package-size: uint,
    coverage-rate: uint,
    delivery-time: uint,
    urgency-level: uint,
    pickup-block: (optional uint),
    delivery-address: (string-ascii 30),
    package-description: (string-ascii 20),
    delivery-status: (string-ascii 20)
  }
)

(define-map token-balances principal uint)

(define-map agent-performance principal uint)

(define-map customer-package-log
  principal
  (list 10 uint)
)

;; Define functions
(define-public (create-package (package-size uint) (coverage-rate uint) (delivery-time uint) 
                                 (urgency-level uint) (delivery-address (string-ascii 30)) 
                                 (package-description (string-ascii 20)))
  (let ((package-id (+ (var-get package-counter) u1)))
    ;; Validate input parameters
    (asserts! (> package-size u0) ERR-PACKAGE-SIZE-INVALID)
    (asserts! (<= coverage-rate u50) ERR-COVERAGE-RATE-INVALID)
    (asserts! (and (> delivery-time u0) (<= delivery-time u10000)) ERR-DELIVERY-TIME-INVALID)
    (asserts! (and (>= urgency-level u1) (<= urgency-level u5)) ERR-URGENCY-LEVEL-INVALID)
    
    (map-set package-registry 
      { package-id: package-id }
      {
        owner: tx-sender,
        delivery-agent: none,
        package-size: package-size,
        coverage-rate: coverage-rate,
        delivery-time: delivery-time,
        urgency-level: urgency-level,
        pickup-block: none,
        delivery-address: delivery-address,
        package-description: package-description,
        delivery-status: "READY"
      }
    )
    
    ;; Update customer's package history - put the new package at the beginning
    (let 
      (
        (current-log (default-to (list) (map-get? customer-package-log tx-sender)))
        (updated-log (unwrap-panic (as-max-len? (concat (list package-id) current-log) u10)))
      )
      ;; Take only up to 10 elements
      (map-set customer-package-log tx-sender updated-log)
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
        pickup-block: (some block-height),
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
    (owner-balance (default-to u0 (map-get? token-balances tx-sender)))
    (base-fee (get package-size package-data))
    (coverage-fee (/ (* (get package-size package-data) (get coverage-rate package-data)) u100))
    (urgency-fee (/ (* base-fee (get urgency-level package-data)) u100))
    (total-fee (+ base-fee coverage-fee urgency-fee))
  )
    ;; Validate package ID and conditions
    (asserts! (<= package-id (var-get package-counter)) ERR-PACKAGE-ID-INVALID)
    (asserts! (is-eq (get owner package-data) tx-sender) ERR-PERMISSION-DENIED)
    (asserts! (is-eq (get delivery-status package-data) "TRANSIT") ERR-PACKAGE-UNAVAILABLE)
    (asserts! (>= (- block-height (unwrap! (get pickup-block package-data) ERR-PACKAGE-UNAVAILABLE)) 
                (get delivery-time package-data)) ERR-DELIVERY-IN-PROGRESS)
    (asserts! (>= owner-balance total-fee) ERR-BALANCE-TOO-LOW)
    
    ;; Process payment
    (map-set token-balances tx-sender (- owner-balance total-fee))
    (map-set token-balances (unwrap! (get delivery-agent package-data) ERR-PACKAGE-UNAVAILABLE) 
      (+ (default-to u0 (map-get? token-balances (unwrap! (get delivery-agent package-data) ERR-PACKAGE-UNAVAILABLE))) 
         total-fee)
    )
    
    ;; Update agent performance
    (let ((current-score (default-to u0 (map-get? agent-performance 
                          (unwrap! (get delivery-agent package-data) ERR-PACKAGE-UNAVAILABLE)))))
      (map-set agent-performance
        (unwrap! (get delivery-agent package-data) ERR-PACKAGE-UNAVAILABLE)
        (+ current-score u1)
      )
    )
    
    ;; Mark package as delivered
    (map-set package-registry { package-id: package-id } (merge package-data { delivery-status: "COMPLETED" }))
    (ok true)
  )
)

(define-public (terminate-package (package-id uint))
  (let (
    (package-data (unwrap! (map-get? package-registry { package-id: package-id }) ERR-PACKAGE-UNAVAILABLE))
  )
    ;; Validate package ID and authorization
    (asserts! (<= package-id (var-get package-counter)) ERR-PACKAGE-ID-INVALID)
    (asserts! (is-eq (get owner package-data) tx-sender) ERR-PERMISSION-DENIED)
    (asserts! (is-eq (get delivery-status package-data) "READY") ERR-PACKAGE-UNAVAILABLE)
    
    ;; Mark package as terminated
    (map-set package-registry { package-id: package-id } (merge package-data { delivery-status: "TERMINATED" }))
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

(define-read-only (get-agent-score (agent principal))
  (default-to u0 (map-get? agent-performance agent))
)

(define-read-only (view-customer-packages (customer principal))
  (default-to (list) (map-get? customer-package-log customer))
)

;; Calculate urgency multiplier
(define-read-only (calculate-urgency-bonus (urgency-level uint))
  (if (and (>= urgency-level u1) (<= urgency-level u5))
      (* urgency-level u1)
      u0)  ;; Return a default value if urgency level is invalid
)

;; Initialize counters and data
(define-data-var package-counter uint u0)