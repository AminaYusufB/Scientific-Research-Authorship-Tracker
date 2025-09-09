(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PAPER-EXISTS (err u101))
(define-constant ERR-PAPER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-CONTRIBUTION (err u103))
(define-constant ERR-REVIEW-EXISTS (err u104))
(define-constant ERR-REVIEW-NOT-FOUND (err u105))
(define-constant ERR-INVALID-SCORE (err u106))
(define-constant ERR-SELF-REVIEW (err u107))
(define-constant ERR-BOUNTY-NOT-FOUND (err u108))
(define-constant ERR-BOUNTY-INACTIVE (err u109))
(define-constant ERR-INSUFFICIENT-FUNDS (err u110))
(define-constant ERR-BOUNTY-EXPIRED (err u111))
(define-constant ERR-SOLUTION-EXISTS (err u112))

(define-data-var dao-treasury uint u0)
(define-data-var bounty-counter uint u0)

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

(define-map research-bounties
    uint
    {
        creator: principal,
        title: (string-ascii 256),
        description: (string-ascii 1000),
        reward: uint,
        expiration: uint,
        solved: bool,
        solver: (optional principal)
    }
)

(define-map bounty-solutions
    { bounty-id: uint, solver: principal }
    {
        solution-hash: (buff 32),
        timestamp: uint,
        validated: bool
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

(define-public (create-bounty (title (string-ascii 256)) (description (string-ascii 1000)) (reward uint) (duration uint))
    (let
        (
            (creator tx-sender)
            (bounty-id (+ (var-get bounty-counter) u1))
            (current-time burn-block-height)
            (expiration (+ current-time duration))
        )
        (asserts! (>= (stx-get-balance creator) reward) ERR-INSUFFICIENT-FUNDS)
        
        (try! (stx-transfer? reward creator (as-contract tx-sender)))
        
        (map-set research-bounties
            bounty-id
            {
                creator: creator,
                title: title,
                description: description,
                reward: reward,
                expiration: expiration,
                solved: false,
                solver: none
            }
        )
        
        (var-set bounty-counter bounty-id)
        (ok bounty-id)
    )
)

(define-public (submit-solution (bounty-id uint) (solution-hash (buff 32)))
    (let
        (
            (solver tx-sender)
            (bounty (unwrap! (map-get? research-bounties bounty-id) ERR-BOUNTY-NOT-FOUND))
            (current-time burn-block-height)
        )
        (asserts! (< current-time (get expiration bounty)) ERR-BOUNTY-EXPIRED)
        (asserts! (not (get solved bounty)) ERR-BOUNTY-INACTIVE)
        (asserts! (is-none (map-get? bounty-solutions {bounty-id: bounty-id, solver: solver})) ERR-SOLUTION-EXISTS)
        
        (map-set bounty-solutions
            {bounty-id: bounty-id, solver: solver}
            {
                solution-hash: solution-hash,
                timestamp: current-time,
                validated: false
            }
        )
        (ok true)
    )
)

(define-public (validate-solution (bounty-id uint) (solver principal))
    (let
        (
            (bounty (unwrap! (map-get? research-bounties bounty-id) ERR-BOUNTY-NOT-FOUND))
            (solution (unwrap! (map-get? bounty-solutions {bounty-id: bounty-id, solver: solver}) ERR-REVIEW-NOT-FOUND))
            (reward (get reward bounty))
        )
        (asserts! (is-eq tx-sender (get creator bounty)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get solved bounty)) ERR-BOUNTY-INACTIVE)
        
        (map-set research-bounties
            bounty-id
            (merge bounty {solved: true, solver: (some solver)})
        )
        
        (map-set bounty-solutions
            {bounty-id: bounty-id, solver: solver}
            (merge solution {validated: true})
        )
        
        (try! (as-contract (stx-transfer? reward tx-sender solver)))
        (ok true)
    )
)

(define-read-only (get-bounty (bounty-id uint))
    (ok (unwrap! (map-get? research-bounties bounty-id) ERR-BOUNTY-NOT-FOUND))
)

(define-read-only (get-solution (bounty-id uint) (solver principal))
    (ok (unwrap! (map-get? bounty-solutions {bounty-id: bounty-id, solver: solver}) ERR-REVIEW-NOT-FOUND))
)

(define-read-only (get-active-bounties)
    (ok (var-get bounty-counter))
)