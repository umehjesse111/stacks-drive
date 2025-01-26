;; Stacks-Drive Smart Contract
;; A decentralized file storage system with Bitcoin incentives.

(define-constant CONTRACT_OWNER tx-sender) ;; Contract owner
(define-constant STORAGE_PRICE_PER_GB u100) ;; Price per GB in micro-STX

;; Data structures
(define-data-var providers (list principal) (list tx-sender)) ;; Initialize with contract owner
(define-map files { file-hash: string } { owner: principal, size: uint }) ;; File storage map

;; Errors
(define-constant ERR_NOT_OWNER (err u100))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u101))
(define-constant ERR_FILE_NOT_FOUND (err u102))
(define-constant ERR_NOT_PROVIDER (err u103))

;; Register as a storage provider
(define-public (register-provider)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set providers (append (var-get providers) (list tx-sender)))
    (ok true)
  )
)

;; Upload a file
(define-public (upload-file (file-hash string) (size uint))
  (let ((payment (* size STORAGE_PRICE_PER_GB)))
    (asserts! (>= (stx-get-balance tx-sender) payment) ERR_INSUFFICIENT_PAYMENT)
    (stx-transfer? payment tx-sender CONTRACT_OWNER)
    (map-set files { file-hash: file-hash } { owner: tx-sender, size: size })
    (ok true)
  )
)

;; Get file details
(define-read-only (get-file (file-hash string))
  (default-to { owner: tx-sender, size: u0 } (map-get? files { file-hash: file-hash }))
)

;; Delete a file (only owner can delete)
(define-public (delete-file (file-hash string))
  (let ((file-details (unwrap! (map-get? files { file-hash: file-hash }) ERR_FILE_NOT_FOUND)))
    (asserts! (is-eq (get owner file-details) tx-sender) ERR_NOT_OWNER)
    (map-delete files { file-hash: file-hash })
    (ok true)
  )
)

;; Check if a user is a storage provider
(define-read-only (is-provider (user principal))
  (contains? (var-get providers) user)
)

;; Add a provider (only contract owner can add)
(define-public (add-provider (user principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set providers (append (var-get providers) (list user)))
    (ok true)
  )
)

;; Remove a provider (only contract owner can remove)
(define-public (remove-provider (user principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set providers (filter (var-get providers) (not (is-eq user))))
    (ok true)
  )
)