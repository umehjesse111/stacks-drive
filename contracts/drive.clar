(define-constant contract-owner tx-sender)
(define-constant storage-fee u10)  
(define-constant max-file-size u1048576)  

;; Storage provider struct
(define-map storage-providers 
  { provider: principal }
  {
    total-space: uint,
    used-space: uint,
    reputation-score: uint,
    active: bool
  }
)

;; File metadata struct
(define-map file-metadata 
  { file-hash: (buff 32) }
  {
    uploader: principal,
    provider: principal,
    file-size: uint,
    upload-time: uint,
    is-available: bool
  }
)

;; Rewards tracking
(define-map provider-rewards 
  { provider: principal }
  { total-rewards: uint }
)

;; Register as a storage provider
(define-public (register-provider (total-space uint))
  (begin
    (asserts! (> total-space u0) (err u1))
    (map-set storage-providers 
      { provider: tx-sender }
      {
        total-space: total-space,
        used-space: u0,
        reputation-score: u100,
        active: true
      }
    )
    (ok true)
  )
)

;; Upload file metadata
(define-public (upload-file 
  (file-hash (buff 32)) 
  (file-size uint)
  (provider principal)
)
  (let 
    (
      (provider-info 
        (unwrap! 
          (map-get? storage-providers { provider: provider }) 
          (err u2)
        )
      )
      (storage-cost (* file-size storage-fee))
    )
    (asserts! (< file-size max-file-size) (err u3))
    (asserts! (>= (get total-space provider-info) 
                  (+ (get used-space provider-info) file-size)) 
      (err u4)
    )
    
    ;; Update provider storage usage
    (map-set storage-providers 
      { provider: provider }
      (merge provider-info 
        { used-space: (+ (get used-space provider-info) file-size) }
      )
    )
    
    ;; Store file metadata
    (map-set file-metadata 
      { file-hash: file-hash }
      {
        uploader: tx-sender,
        provider: provider,
        file-size: file-size,
        upload-time: block-height,
        is-available: true
      }
    )
    
    (ok true)
  )
)

;; Retrieve file metadata
(define-read-only (get-file-metadata (file-hash (buff 32)))
  (map-get? file-metadata { file-hash: file-hash })
)

;; Claim storage provider rewards
(define-public (claim-rewards)
  (let 
    (
      (provider-info 
        (unwrap! 
          (map-get? storage-providers { provider: tx-sender }) 
          (err u5)
        )
      )
      (current-rewards 
        (default-to u0 
          (get total-rewards 
            (unwrap-panic 
              (map-get? provider-rewards { provider: tx-sender })
            )
          )
        )
      )
      (reward-amount 
        (* (get used-space provider-info) storage-fee)
      )
    )
    (asserts! (get active provider-info) (err u6))
    
    ;; Update rewards
    (map-set provider-rewards 
      { provider: tx-sender }
      { total-rewards: (+ current-rewards reward-amount) }
    )
    
    ;; Transfer rewards (placeholder - actual transfer mechanism would depend on STX/BTC integration)
    (stx-transfer? reward-amount tx-sender contract-owner)
  )
)

;; Deactivate storage provider
(define-public (deactivate-provider)
  (let 
    (
      (provider-info 
        (unwrap! 
          (map-get? storage-providers { provider: tx-sender }) 
          (err u7)
        )
      )
    )
    (asserts! (is-eq (get used-space provider-info) u0) (err u8))
    
    (map-set storage-providers 
      { provider: tx-sender }
      (merge provider-info { active: false })
    )
    
    (ok true)
  )
)