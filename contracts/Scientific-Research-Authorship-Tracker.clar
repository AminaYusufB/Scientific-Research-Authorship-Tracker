(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PAPER-EXISTS (err u101))
(define-constant ERR-PAPER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-CONTRIBUTION (err u103))
(define-constant ERR-REVIEW-EXISTS (err u104))
(define-constant ERR-REVIEW-NOT-FOUND (err u105))
(define-constant ERR-INVALID-SCORE (err u106))
(define-constant ERR-SELF-REVIEW (err u107))

(define-data-var dao-treasury uint u0)

(define-map papers 
    { paper-hash: (buff 32) }
    {
        author: principal,
        title: (string-ascii 256),
        timestamp: uint,
        citations: (list 200 (buff 32)),
        contributors: (list 50 principal),
        contribution-weights: (list 50 uint)
    }
)

(define-map researcher-stats
    principal
    {
        papers-authored: uint,
        total-citations: uint,
        contribution-score: uint
    }
)

(define-map paper-reviews
    { paper-hash: (buff 32), reviewer: principal }
    {
        score: uint,
        timestamp: uint,
        review-text: (string-ascii 500)
    }
)

(define-map reviewer-stats
    principal
    {
        reviews-completed: uint,
        average-score-given: uint,
        reputation-score: uint
    }
)

(define-non-fungible-token research-token (buff 32))

(define-public (publish-paper (paper-hash (buff 32)) (title (string-ascii 256)))
    (let
        (
            (author tx-sender)

            (current-time burn-block-height)
        )
        (asserts! (is-none (map-get? papers {paper-hash: paper-hash})) ERR-PAPER-EXISTS)
        
        (try! (nft-mint? research-token paper-hash author))
        
        (map-set papers
            {paper-hash: paper-hash}
            {
                author: author,
                title: title,

                timestamp: current-time,
                citations: (list),
                contributors: (list author),
                contribution-weights: (list u100)
            }
        )
        
        (match (map-get? researcher-stats author)
            prev-stats
            (map-set researcher-stats
                author
                {
                    papers-authored: (+ (get papers-authored prev-stats) u1),
                    total-citations: (get total-citations prev-stats),
                    contribution-score: (+ (get contribution-score prev-stats) u100)
                }
            )
            (map-set researcher-stats
                author
                {
                    papers-authored: u1,
                    total-citations: u0,
                    contribution-score: u100
                }
            )
        )
        (ok true)
    )
)

(define-public (add-citation (paper-hash (buff 32)) (cited-paper-hash (buff 32)))
    (let
        (
            (paper (unwrap! (map-get? papers {paper-hash: paper-hash}) ERR-PAPER-NOT-FOUND))
            (cited-author (get author (unwrap! (map-get? papers {paper-hash: cited-paper-hash}) ERR-PAPER-NOT-FOUND)))
        )
        (asserts! (is-eq tx-sender (get author paper)) ERR-NOT-AUTHORIZED)
        
        (map-set papers
            {paper-hash: paper-hash}
            (merge paper {citations: (unwrap! (as-max-len? (append (get citations paper) cited-paper-hash) u200) ERR-NOT-AUTHORIZED)})
        )
        
        (match (map-get? researcher-stats cited-author)
            prev-stats
            (map-set researcher-stats
                cited-author
                (merge prev-stats {total-citations: (+ (get total-citations prev-stats) u1)})
            )
            (map-set researcher-stats
                cited-author
                {
                    papers-authored: u0,
                    total-citations: u1,
                    contribution-score: u0
                }
            )
        )
        (ok true)
    )
)

(define-public (add-contributor (paper-hash (buff 32)) (contributor principal) (weight uint))
    (let
        (
            (paper (unwrap! (map-get? papers {paper-hash: paper-hash}) ERR-PAPER-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get author paper)) ERR-NOT-AUTHORIZED)
        (asserts! (<= weight u100) ERR-INVALID-CONTRIBUTION)
        
        (map-set papers
            {paper-hash: paper-hash}
            (merge paper 
                {
                    contributors: (unwrap! (as-max-len? (append (get contributors paper) contributor) u50) ERR-NOT-AUTHORIZED),
                    contribution-weights: (unwrap! (as-max-len? (append (get contribution-weights paper) weight) u50) ERR-NOT-AUTHORIZED)
                }
            )
        )
        
        (match (map-get? researcher-stats contributor)
            prev-stats
            (map-set researcher-stats
                contributor
                (merge prev-stats {contribution-score: (+ (get contribution-score prev-stats) weight)})
            )
            (map-set researcher-stats
                contributor
                {
                    papers-authored: u0,
                    total-citations: u0,
                    contribution-score: weight
                }
            )
        )
        (ok true)
    )
)

(define-read-only (get-paper-details (paper-hash (buff 32)))
    (ok (unwrap! (map-get? papers {paper-hash: paper-hash}) ERR-PAPER-NOT-FOUND))
)

(define-read-only (get-researcher-metrics (researcher principal))
    (ok (unwrap! (map-get? researcher-stats researcher) ERR-NOT-AUTHORIZED))
)

(define-public (submit-review (paper-hash (buff 32)) (score uint) (review-text (string-ascii 500)))
    (let
        (
            (reviewer tx-sender)
            (paper (unwrap! (map-get? papers {paper-hash: paper-hash}) ERR-PAPER-NOT-FOUND))
            (current-time burn-block-height)
        )
        (asserts! (not (is-eq reviewer (get author paper))) ERR-SELF-REVIEW)
        (asserts! (and (>= score u1) (<= score u10)) ERR-INVALID-SCORE)
        (asserts! (is-none (map-get? paper-reviews {paper-hash: paper-hash, reviewer: reviewer})) ERR-REVIEW-EXISTS)
        
        (map-set paper-reviews
            {paper-hash: paper-hash, reviewer: reviewer}
            {
                score: score,
                timestamp: current-time,
                review-text: review-text
            }
        )
        
        (match (map-get? reviewer-stats reviewer)
            prev-stats
            (let
                (
                    (total-reviews (get reviews-completed prev-stats))
                    (prev-avg (get average-score-given prev-stats))
                    (new-avg (/ (+ (* prev-avg total-reviews) score) (+ total-reviews u1)))
                )
                (map-set reviewer-stats
                    reviewer
                    {
                        reviews-completed: (+ total-reviews u1),
                        average-score-given: new-avg,
                        reputation-score: (+ (get reputation-score prev-stats) u10)
                    }
                )
            )
            (map-set reviewer-stats
                reviewer
                {
                    reviews-completed: u1,
                    average-score-given: score,
                    reputation-score: u10
                }
            )
        )
        (ok true)
    )
)

(define-read-only (get-paper-review (paper-hash (buff 32)) (reviewer principal))
    (ok (unwrap! (map-get? paper-reviews {paper-hash: paper-hash, reviewer: reviewer}) ERR-REVIEW-NOT-FOUND))
)

(define-read-only (get-reviewer-stats (reviewer principal))
    (ok (unwrap! (map-get? reviewer-stats reviewer) ERR-NOT-AUTHORIZED))
)