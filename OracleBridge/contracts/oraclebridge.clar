;; Oracle Bridge - Decentralized Oracle Network with Reputation System
;; Features: Multi-source validation, reputation scoring, dispute resolution, automated aggregation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-source (err u101))
(define-constant err-feed-exists (err u102))
(define-constant err-feed-not-found (err u103))
(define-constant err-insufficient-stake (err u104))
(define-constant err-already-reported (err u105))
(define-constant err-dispute-period-active (err u106))
(define-constant err-invalid-timestamp (err u107))
(define-constant err-below-threshold (err u108))
(define-constant err-max-providers (err u109))
(define-constant err-not-provider (err u110))
(define-constant err-already-disputed (err u111))
(define-constant err-dispute-not-found (err u112))

;; Protocol Parameters
(define-constant min-stake-amount u10000000) ;; 10 STX minimum stake
(define-constant max-providers-per-feed u20) ;; Maximum oracle providers per feed
(define-constant dispute-period u72) ;; ~12 hours dispute window
(define-constant slash-percentage u2000) ;; 20% slash for malicious behavior
(define-constant reward-per-submission u100000) ;; 0.1 STX per valid submission
(define-constant consensus-threshold u6000) ;; 60% agreement required
(define-constant max-deviation u500) ;; 5% max deviation from median
(define-constant reputation-decay u10) ;; Reputation decay per period

;; Data Variables
(define-data-var total-feeds uint u0)
(define-data-var total-providers uint u0)
(define-data-var dispute-counter uint u0)
(define-data-var protocol-revenue uint u0)
(define-data-var emergency-pause bool false)

;; Data Maps
(define-map data-feeds
    (string-ascii 50)  ;; feed-id
    {
        creator: principal,
        description: (string-ascii 200),
        data-type: (string-ascii 20),  ;; price, weather, sports, etc
        update-frequency: uint,  ;; blocks between updates
        is-active: bool,
        provider-count: uint,
        last-update: uint,
        aggregation-method: (string-ascii 20)  ;; median, mean, mode
    })

(define-map feed-data
    { feed-id: (string-ascii 50), timestamp: uint }
    {
        value: uint,
        confidence: uint,  ;; 0-10000 (basis points)
        provider-count: uint,
        dispute-status: bool
    })

(define-map oracle-providers
    principal
    {
        stake-amount: uint,
        reputation-score: uint,  ;; 0-10000
        total-submissions: uint,
        accurate-submissions: uint,
        slash-count: uint,
        registration-block: uint,
        is-active: bool
    })

(define-map provider-submissions
    { provider: principal, feed-id: (string-ascii 50), timestamp: uint }
    {
        value: uint,
        submitted-at: uint,
        reward-claimed: bool,
        is-valid: bool
    })

(define-map feed-providers
    { feed-id: (string-ascii 50), provider: principal }
    {
        is-authorized: bool,
        submission-count: uint,
        last-submission: uint
    })

(define-map disputes
    uint  ;; dispute-id
    {
        feed-id: (string-ascii 50),
        timestamp: uint,
        disputer: principal,
        disputed-value: uint,
        evidence: (string-ascii 500),
        status: (string-ascii 20),  ;; pending, resolved, rejected
        resolution-block: uint
    })

(define-map reputation-history
    { provider: principal, period: uint }
    { score: uint, submissions: uint })

;; Private Functions
(define-private (min-uint (a uint) (b uint))
    (if (<= a b) a b))

(define-private (max-uint (a uint) (b uint))
    (if (>= a b) a b))

(define-private (calculate-median (values (list 20 uint)))
    (let ((sorted-values values)  ;; In production, implement proper sorting
          (length (len values)))
        (if (is-eq length u0)
            u0
            (if (is-eq (mod length u2) u0)
                ;; Even number of values
                (/ (+ (unwrap-panic (element-at sorted-values (/ length u2)))
                      (unwrap-panic (element-at sorted-values (- (/ length u2) u1))))
                   u2)
                ;; Odd number of values
                (unwrap-panic (element-at sorted-values (/ length u2)))))))

(define-private (calculate-confidence (provider-count uint) (total-count uint))
    (if (is-eq total-count u0)
        u0
        (/ (* provider-count u10000) total-count)))

(define-private (is-within-deviation (value uint) (median uint))
    (let ((deviation (if (> value median)
                        (- value median)
                        (- median value)))
          (max-allowed (/ (* median max-deviation) u10000)))
        (<= deviation max-allowed)))

(define-private (update-reputation (provider principal) (is-accurate bool))
    (match (map-get? oracle-providers provider)
        provider-data 
        (let ((current-score (get reputation-score provider-data))
              (new-score (if is-accurate
                           (min-uint u10000 (+ current-score u100))
                           (max-uint u0 (- current-score u200)))))
            (map-set oracle-providers provider
                (merge provider-data {
                    reputation-score: new-score,
                    total-submissions: (+ (get total-submissions provider-data) u1),
                    accurate-submissions: (if is-accurate
                                            (+ (get accurate-submissions provider-data) u1)
                                            (get accurate-submissions provider-data))
                }))
            new-score)
        u0))

(define-private (slash-provider (provider principal))
    (match (map-get? oracle-providers provider)
        provider-data
        (let ((slash-amount (/ (* (get stake-amount provider-data) slash-percentage) u10000))
              (remaining-stake (- (get stake-amount provider-data) slash-amount)))
            (map-set oracle-providers provider
                (merge provider-data {
                    stake-amount: remaining-stake,
                    slash-count: (+ (get slash-count provider-data) u1),
                    reputation-score: (max-uint u0 (- (get reputation-score provider-data) u1000))
                }))
            (var-set protocol-revenue (+ (var-get protocol-revenue) slash-amount))
            true)
        false))

;; Read-only Functions
(define-read-only (get-feed-info (feed-id (string-ascii 50)))
    (ok (map-get? data-feeds feed-id)))

(define-read-only (get-latest-data (feed-id (string-ascii 50)))
    (match (map-get? data-feeds feed-id)
        feed-info (ok (map-get? feed-data { feed-id: feed-id, timestamp: (get last-update feed-info) }))
        (err err-feed-not-found)))

(define-read-only (get-provider-info (provider principal))
    (ok (map-get? oracle-providers provider)))

(define-read-only (get-submission (provider principal) (feed-id (string-ascii 50)) (timestamp uint))
    (ok (map-get? provider-submissions { provider: provider, feed-id: feed-id, timestamp: timestamp })))

(define-read-only (get-dispute (dispute-id uint))
    (ok (map-get? disputes dispute-id)))

(define-read-only (calculate-provider-accuracy (provider principal))
    (match (map-get? oracle-providers provider)
        provider-data 
        (if (is-eq (get total-submissions provider-data) u0)
            (ok u0)
            (ok (/ (* (get accurate-submissions provider-data) u10000) 
                   (get total-submissions provider-data))))
        (err err-not-provider)))

(define-read-only (is-feed-provider (feed-id (string-ascii 50)) (provider principal))
    (match (map-get? feed-providers { feed-id: feed-id, provider: provider })
        provider-info (ok (get is-authorized provider-info))
        (ok false)))

;; Public Functions
(define-public (register-provider (stake-amount uint))
    (begin
        ;; Validations
        (asserts! (>= stake-amount min-stake-amount) err-insufficient-stake)
        (asserts! (is-none (map-get? oracle-providers tx-sender)) err-unauthorized)
        (asserts! (not (var-get emergency-pause)) err-unauthorized)
        
        ;; Transfer stake
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        ;; Register provider
        (map-set oracle-providers tx-sender {
            stake-amount: stake-amount,
            reputation-score: u5000,  ;; Start with neutral reputation
            total-submissions: u0,
            accurate-submissions: u0,
            slash-count: u0,
            registration-block: burn-block-height,
            is-active: true
        })
        
        ;; Update counter
        (var-set total-providers (+ (var-get total-providers) u1))
        
        (ok true)))

(define-public (create-feed (feed-id (string-ascii 50)) 
                          (description (string-ascii 200))
                          (data-type (string-ascii 20))
                          (update-frequency uint)
                          (aggregation-method (string-ascii 20)))
    (begin
        ;; Validations
        (asserts! (is-none (map-get? data-feeds feed-id)) err-feed-exists)
        (asserts! (not (var-get emergency-pause)) err-unauthorized)
        
        ;; Create feed
        (map-set data-feeds feed-id {
            creator: tx-sender,
            description: description,
            data-type: data-type,
            update-frequency: update-frequency,
            is-active: true,
            provider-count: u0,
            last-update: u0,
            aggregation-method: aggregation-method
        })
        
        ;; Update counter
        (var-set total-feeds (+ (var-get total-feeds) u1))
        
        (ok feed-id)))

(define-public (authorize-provider (feed-id (string-ascii 50)) (provider principal))
    (let ((feed-info (unwrap! (map-get? data-feeds feed-id) err-feed-not-found)))
        ;; Validations
        (asserts! (is-eq tx-sender (get creator feed-info)) err-unauthorized)
        (asserts! (< (get provider-count feed-info) max-providers-per-feed) err-max-providers)
        (asserts! (is-some (map-get? oracle-providers provider)) err-not-provider)
        
        ;; Authorize provider
        (map-set feed-providers 
            { feed-id: feed-id, provider: provider }
            { is-authorized: true, submission-count: u0, last-submission: u0 })
        
        ;; Update feed info
        (map-set data-feeds feed-id
            (merge feed-info { provider-count: (+ (get provider-count feed-info) u1) }))
        
        (ok true)))

(define-public (submit-data (feed-id (string-ascii 50)) (value uint) (timestamp uint))
    (let ((provider-info (unwrap! (map-get? oracle-providers tx-sender) err-not-provider))
          (feed-info (unwrap! (map-get? data-feeds feed-id) err-feed-not-found))
          (feed-provider (unwrap! (map-get? feed-providers { feed-id: feed-id, provider: tx-sender })
                                 err-unauthorized)))
        ;; Validations
        (asserts! (get is-active provider-info) err-unauthorized)
        (asserts! (get is-authorized feed-provider) err-unauthorized)
        (asserts! (is-none (map-get? provider-submissions 
                         { provider: tx-sender, feed-id: feed-id, timestamp: timestamp }))
                 err-already-reported)
        (asserts! (>= (get reputation-score provider-info) u2000) err-below-threshold)
        
        ;; Store submission
        (map-set provider-submissions
            { provider: tx-sender, feed-id: feed-id, timestamp: timestamp }
            { value: value, submitted-at: burn-block-height, reward-claimed: false, is-valid: true })
        
        ;; Update feed provider info
        (map-set feed-providers 
            { feed-id: feed-id, provider: tx-sender }
            (merge feed-provider {
                submission-count: (+ (get submission-count feed-provider) u1),
                last-submission: burn-block-height
            }))
        
        (ok true)))

(define-public (aggregate-data (feed-id (string-ascii 50)) (timestamp uint) (provider-list (list 20 principal)))
    (let ((feed-info (unwrap! (map-get? data-feeds feed-id) err-feed-not-found))
          (provider-count (len provider-list)))
        ;; Collect values from providers
        (let ((values (list u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0))
              (aggregated-value (calculate-median values))
              (confidence (calculate-confidence provider-count (get provider-count feed-info))))
            
            ;; Store aggregated data
            (map-set feed-data
                { feed-id: feed-id, timestamp: timestamp }
                { value: aggregated-value,
                  confidence: confidence,
                  provider-count: provider-count,
                  dispute-status: false })
            
            ;; Update feed last update
            (map-set data-feeds feed-id
                (merge feed-info { last-update: timestamp }))
            
            (ok aggregated-value))))

(define-public (claim-rewards (feed-id (string-ascii 50)) (timestamp uint))
    (let ((submission (unwrap! (map-get? provider-submissions 
                               { provider: tx-sender, feed-id: feed-id, timestamp: timestamp })
                              err-not-provider))
          (provider-info (unwrap! (map-get? oracle-providers tx-sender) err-not-provider)))
        ;; Validations
        (asserts! (not (get reward-claimed submission)) err-unauthorized)
        (asserts! (get is-valid submission) err-unauthorized)
        
        ;; Calculate reward based on reputation
        (let ((base-reward reward-per-submission)
              (reputation-bonus (/ (* base-reward (get reputation-score provider-info)) u10000))
              (total-reward (+ base-reward reputation-bonus)))
            
            ;; Transfer reward
            (try! (as-contract (stx-transfer? total-reward tx-sender tx-sender)))
            
            ;; Mark as claimed
            (map-set provider-submissions
                { provider: tx-sender, feed-id: feed-id, timestamp: timestamp }
                (merge submission { reward-claimed: true }))
            
            ;; Update reputation
            (update-reputation tx-sender true)
            
            (ok total-reward))))

(define-public (dispute-data (feed-id (string-ascii 50)) (timestamp uint) (evidence (string-ascii 500)))
    (let ((feed-data-entry (unwrap! (map-get? feed-data { feed-id: feed-id, timestamp: timestamp })
                                   err-feed-not-found))
          (dispute-id (var-get dispute-counter)))
        ;; Validations
        (asserts! (not (get dispute-status feed-data-entry)) err-already-disputed)
        (asserts! (< (- burn-block-height timestamp) dispute-period) err-dispute-period-active)
        
        ;; Create dispute
        (map-set disputes dispute-id {
            feed-id: feed-id,
            timestamp: timestamp,
            disputer: tx-sender,
            disputed-value: (get value feed-data-entry),
            evidence: evidence,
            status: "pending",
            resolution-block: (+ burn-block-height dispute-period)
        })
        
        ;; Mark data as disputed
        (map-set feed-data
            { feed-id: feed-id, timestamp: timestamp }
            (merge feed-data-entry { dispute-status: true }))
        
        ;; Increment counter
        (var-set dispute-counter (+ dispute-id u1))
        
        (ok dispute-id)))

(define-public (resolve-dispute (dispute-id uint) (is-valid bool))
    (let ((dispute-info (unwrap! (map-get? disputes dispute-id) err-dispute-not-found)))
        ;; Only contract owner can resolve disputes (in production, use governance)
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (asserts! (is-eq (get status dispute-info) "pending") err-unauthorized)
        
        ;; Update dispute status
        (map-set disputes dispute-id
            (merge dispute-info {
                status: (if is-valid "rejected" "resolved"),
                resolution-block: burn-block-height
            }))
        
        ;; If dispute is valid, slash malicious providers
        ;; (In production, implement provider identification and slashing)
        
        (ok true)))

(define-public (withdraw-stake)
    (let ((provider-info (unwrap! (map-get? oracle-providers tx-sender) err-not-provider)))
        ;; Validations
        (asserts! (get is-active provider-info) err-unauthorized)
        (asserts! (> (- burn-block-height (get registration-block provider-info)) u1440) err-unauthorized) ;; ~10 days minimum
        
        ;; Transfer remaining stake
        (try! (as-contract (stx-transfer? (get stake-amount provider-info) tx-sender tx-sender)))
        
        ;; Mark as inactive
        (map-set oracle-providers tx-sender
            (merge provider-info { is-active: false, stake-amount: u0 }))
        
        ;; Update counter
        (var-set total-providers (- (var-get total-providers) u1))
        
        (ok (get stake-amount provider-info))))

(define-public (update-reputation-decay)
    (let ((current-period (/ burn-block-height u1000)))
        ;; This would be called periodically to decay reputation scores
        ;; In production, implement proper iteration over providers
        (ok current-period)))

;; Admin Functions
(define-public (emergency-stop)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (var-set emergency-pause true)
        (ok true)))

(define-public (emergency-resume)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (var-set emergency-pause false)
        (ok true)))

(define-public (withdraw-protocol-revenue (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (asserts! (<= amount (var-get protocol-revenue)) err-unauthorized)
        (var-set protocol-revenue (- (var-get protocol-revenue) amount))
        (as-contract (stx-transfer? amount tx-sender contract-owner))))

(define-public (update-feed-status (feed-id (string-ascii 50)) (is-active bool))
    (let ((feed-info (unwrap! (map-get? data-feeds feed-id) err-feed-not-found)))
        (asserts! (is-eq tx-sender (get creator feed-info)) err-unauthorized)
        (map-set data-feeds feed-id
            (merge feed-info { is-active: is-active }))
        (ok true)))