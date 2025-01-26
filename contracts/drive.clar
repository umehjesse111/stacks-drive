(define-constant contract-owner tx-sender)
(define-constant storage-fee u10)  
(define-constant max-file-size u1048576)  


;; Validation functions
(define-private (is-valid-provider (provider principal))
  (is-some (map-get? storage-providers { provider: provider }))
)

(define-private (is-valid-file-hash (file-hash (buff 32)))
  (and 
    (> (len file-hash) u0)
    (< (len file-hash) u33)
  )
)

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
  (begin
    ;; Validate inputs
    (asserts! (is-valid-file-hash file-hash) (err u9))
    (asserts! (is-valid-provider provider) (err u10))
    
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
        (match (map-get? provider-rewards { provider: tx-sender })
          rewards (get total-rewards rewards)
          u0
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

;;Delete File Metadata
;; Enhanced Delete File Metadata Function
(define-public (delete-file (file-hash (buff 32)))
  (begin
    ;; Validate file hash input
    (asserts! (is-valid-file-hash file-hash) (err u14))
    
    (let 
      (
        (file-info 
          (unwrap! 
            (map-get? file-metadata { file-hash: file-hash }) 
            (err u11)
          )
        )
      )
      ;; Ensure only the uploader can delete the file
      (asserts! (is-eq tx-sender (get uploader file-info)) (err u12))
      
      ;; Reduce used space for the provider
      (let 
        (
          (provider-info 
            (unwrap! 
              (map-get? storage-providers { provider: (get provider file-info) }) 
              (err u13)
            )
          )
        )
        ;; Update provider's used space
        (map-set storage-providers 
          { provider: (get provider file-info) }
          (merge provider-info 
            { used-space: (- (get used-space provider-info) (get file-size file-info)) }
          )
        )
      )
      
      ;; Remove file metadata
      (map-delete file-metadata { file-hash: file-hash })
      
      (ok true)
    )
  )
)